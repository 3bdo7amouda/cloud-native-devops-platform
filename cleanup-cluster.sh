#!/bin/bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
STACK_TAG="${STACK_TAG:-platform}"

log() { echo "[$(date +'%H:%M:%S')] $1"; }

confirm() {
    [[ "${1:-}" == "--confirm" ]] && return
    read -p "Delete all platform resources? (yes/no): " -r
    [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]] || exit 0
}

setup_cluster() {
    log "Setting up cluster connection..."
    
    if ! aws sts get-caller-identity &>/dev/null; then
        log "ERROR: AWS credentials not configured"
        exit 1
    fi
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        CLUSTER_NAME=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters[0]' --output text)
        [[ -z "$CLUSTER_NAME" || "$CLUSTER_NAME" == "None" ]] && { log "ERROR: No cluster found"; exit 1; }
    fi
    
    log "Cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &>/dev/null
    kubectl cluster-info &>/dev/null || { log "ERROR: Cannot connect to cluster"; exit 1; }
}

cleanup_platform_ingress() {
    log "Removing platform ingress..."
    kubectl delete -f k8s-config/ingress-argocd.yaml --ignore-not-found &>/dev/null || true
    kubectl delete -f k8s-config/ingress-sonarqube.yaml --ignore-not-found &>/dev/null || true
    kubectl delete -f k8s-config/ingress-nexus.yaml --ignore-not-found &>/dev/null || true
    kubectl delete -f k8s-config/ingress-vault.yaml --ignore-not-found &>/dev/null || true

    if kubectl -n argocd get ingress platform-ingress &>/dev/null; then
        kubectl -n argocd wait --for=delete ingress/platform-ingress --timeout=5m &>/dev/null || true
    fi
    if kubectl -n sonarqube get ingress sonarqube-ingress &>/dev/null; then
        kubectl -n sonarqube wait --for=delete ingress/sonarqube-ingress --timeout=5m &>/dev/null || true
    fi
    if kubectl -n nexus get ingress nexus-ingress &>/dev/null; then
        kubectl -n nexus wait --for=delete ingress/nexus-ingress --timeout=5m &>/dev/null || true
    fi
    if kubectl -n vault get ingress vault-ingress &>/dev/null; then
        kubectl -n vault wait --for=delete ingress/vault-ingress --timeout=5m &>/dev/null || true
    fi
}

cleanup_target_group_binding() {
    log "Removing TargetGroupBinding..."
    kubectl delete targetgroupbinding --all -A --ignore-not-found &>/dev/null || true
}

cleanup_aws_load_balancers() {
    log "Cleaning up AWS load balancers tagged with ingress stack '${STACK_TAG}'..."

    if ! aws sts get-caller-identity &>/dev/null; then
        log "WARNING: AWS credentials not configured; skipping AWS load balancer cleanup"
        return
    fi

    local lb_arns tg_arns
    lb_arns=$(aws resourcegroupstaggingapi get-resources \
        --region "$AWS_REGION" \
        --resource-type-filters elasticloadbalancing:loadbalancer \
        --tag-filters Key=elbv2.k8s.aws/cluster,Values="$CLUSTER_NAME" Key=ingress.k8s.aws/stack,Values="$STACK_TAG" \
        --query 'ResourceTagMappingList[].ResourceARN' \
        --output text 2>/dev/null || true)

    if [[ -n "$lb_arns" ]]; then
        for arn in $lb_arns; do
            log "Deleting load balancer: $arn"
            aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$arn" &>/dev/null || true
        done

        for arn in $lb_arns; do
            for _ in {1..30}; do
                if aws elbv2 describe-load-balancers --region "$AWS_REGION" --load-balancer-arns "$arn" &>/dev/null; then
                    sleep 10
                else
                    break
                fi
            done
        done
    else
        log "No tagged load balancers found"
    fi

    tg_arns=$(aws resourcegroupstaggingapi get-resources \
        --region "$AWS_REGION" \
        --resource-type-filters elasticloadbalancing:targetgroup \
        --tag-filters Key=elbv2.k8s.aws/cluster,Values="$CLUSTER_NAME" Key=ingress.k8s.aws/stack,Values="$STACK_TAG" \
        --query 'ResourceTagMappingList[].ResourceARN' \
        --output text 2>/dev/null || true)

    if [[ -n "$tg_arns" ]]; then
        for arn in $tg_arns; do
            log "Deleting target group: $arn"
            aws elbv2 delete-target-group --region "$AWS_REGION" --target-group-arn "$arn" &>/dev/null || true
        done
    else
        log "No tagged target groups found"
    fi
}

cleanup_helm_releases() {
    log "Uninstalling Helm releases..."
    helm uninstall sonarqube -n sonarqube --wait --timeout 10m &>/dev/null || true
    helm uninstall external-secrets -n external-secrets --wait --timeout 10m &>/dev/null || true
    helm uninstall argocd -n argocd --wait --timeout 10m &>/dev/null || true
    helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 10m &>/dev/null || true
    helm uninstall aws-load-balancer-controller -n kube-system --wait --timeout 10m &>/dev/null || true
}

cleanup_service_account() {
    log "Removing AWS Load Balancer Controller ServiceAccount..."
    kubectl delete sa aws-load-balancer-controller -n kube-system --ignore-not-found &>/dev/null || true
}

cleanup_lbc_cluster_resources() {
    log "Removing AWS Load Balancer Controller cluster-scoped resources (if any)..."
    kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found &>/dev/null || true
    kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found &>/dev/null || true
}

cleanup_namespaces() {
    log "Deleting namespaces..."
    kubectl delete namespace sonarqube --timeout=120s --ignore-not-found &>/dev/null || true
    kubectl delete namespace external-secrets --timeout=120s --ignore-not-found &>/dev/null || true
    kubectl delete namespace ingress-nginx --timeout=120s --ignore-not-found &>/dev/null || true
    kubectl delete namespace argocd --timeout=120s --ignore-not-found &>/dev/null || true
}

verify() {
    log "Verifying cleanup..."
    echo ""
    
    local releases
    releases=$(helm list -A 2>/dev/null | grep -E 'argocd|ingress-nginx|aws-load-balancer-controller|external-secrets|sonarqube' || true)
    [[ -z "$releases" ]] && log "Helm releases removed" || log "WARNING: Some Helm releases still exist"
    
    local namespaces
    namespaces=$(kubectl get ns 2>/dev/null | grep -E 'argocd|ingress-nginx|external-secrets|sonarqube' || true)
    [[ -z "$namespaces" ]] && log "Namespaces removed" || log "WARNING: Some namespaces still exist"
    
    local sa
    sa=$(kubectl get sa aws-load-balancer-controller -n kube-system 2>/dev/null || true)
    [[ -z "$sa" ]] && log "ServiceAccount removed" || log "WARNING: ServiceAccount still exists"
    
    echo ""
    log "Cleanup complete"
}

main() {
    log "Starting platform cleanup..."
    confirm "${1:-}"
    setup_cluster
    cleanup_platform_ingress
    cleanup_target_group_binding
    cleanup_aws_load_balancers
    cleanup_helm_releases
    cleanup_service_account
    cleanup_lbc_cluster_resources
    cleanup_namespaces
    verify
    log "Cluster ready for fresh deployment"
}

main "${1:-}"
