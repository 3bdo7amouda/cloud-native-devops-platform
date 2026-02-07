#!/bin/bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"

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
    kubectl delete -f k8s-config/platform-ingress.yaml --ignore-not-found &>/dev/null || true
}

cleanup_target_group_binding() {
    log "Removing TargetGroupBinding..."
    kubectl delete targetgroupbinding ingress-nlb-tgb -n ingress-nginx --ignore-not-found &>/dev/null || true
}

cleanup_helm_releases() {
    log "Uninstalling Helm releases..."
    helm uninstall argocd -n argocd --wait --timeout 5m &>/dev/null || true
    helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 5m &>/dev/null || true
    helm uninstall aws-load-balancer-controller -n kube-system --wait --timeout 5m &>/dev/null || true
}

cleanup_service_account() {
    log "Removing AWS Load Balancer Controller ServiceAccount..."
    kubectl delete sa aws-load-balancer-controller -n kube-system --ignore-not-found &>/dev/null || true
}

cleanup_namespaces() {
    log "Deleting namespaces..."
    kubectl delete namespace ingress-nginx --timeout=60s --ignore-not-found &>/dev/null || true
    kubectl delete namespace argocd --timeout=60s --ignore-not-found &>/dev/null || true
}

verify() {
    log "Verifying cleanup..."
    echo ""
    
    local releases=$(helm list -A 2>/dev/null | grep -E 'argocd|ingress-nginx|aws-load-balancer-controller' || true)
    [[ -z "$releases" ]] && log "✓ Helm releases removed" || log "⚠ Some Helm releases still exist"
    
    local namespaces=$(kubectl get ns 2>/dev/null | grep -E 'argocd|ingress-nginx' || true)
    [[ -z "$namespaces" ]] && log "✓ Namespaces removed" || log "⚠ Some namespaces still exist"
    
    local sa=$(kubectl get sa aws-load-balancer-controller -n kube-system 2>/dev/null || true)
    [[ -z "$sa" ]] && log "✓ ServiceAccount removed" || log "⚠ ServiceAccount still exists"
    
    echo ""
    log "Cleanup complete!"
}

main() {
    log "Starting platform cleanup..."
    confirm "${1:-}"
    setup_cluster
    cleanup_platform_ingress
    cleanup_target_group_binding
    cleanup_helm_releases
    cleanup_service_account
    cleanup_namespaces
    verify
    log "Cluster ready for fresh deployment"
}

main "${1:-}"
