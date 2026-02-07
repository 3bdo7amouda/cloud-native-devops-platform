#!/bin/bash

##############################################################################
# Kubernetes Cluster Cleanup Script
# Removes all platform resources from EKS cluster
# Usage: ./cleanup-cluster.sh [--confirm]
##############################################################################

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"

##############################################################################
# Functions
##############################################################################

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

cleanup_resources() {
    log "Cleaning up ingress resources..."
    kubectl delete ingress -A --all --timeout=60s --ignore-not-found &>/dev/null || true
    
    log "Cleaning up TargetGroupBindings..."
    if kubectl get crd targetgroupbindings.elbv2.k8s.aws &>/dev/null; then
        kubectl get targetgroupbinding -A -o name 2>/dev/null | while read -r tgb; do
            kubectl patch $tgb -p '{"metadata":{"finalizers":[]}}' --type=merge &>/dev/null || true
            kubectl delete $tgb --timeout=30s &>/dev/null || true
        done
    fi
}

cleanup_helm() {
    log "Uninstalling Helm releases..."
    helm uninstall argocd -n argocd --wait --timeout 5m &>/dev/null || true
    helm uninstall sonarqube -n sonarqube --wait --timeout 5m &>/dev/null || true
    helm uninstall external-secrets -n external-secrets --wait --timeout 5m &>/dev/null || true
    helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 5m &>/dev/null || true
    helm uninstall aws-load-balancer-controller -n kube-system --wait --timeout 5m &>/dev/null || true
}

cleanup_k8s() {
    log "Cleaning up Kubernetes resources..."
    kubectl delete sa aws-load-balancer-controller -n kube-system --ignore-not-found &>/dev/null || true
    
    for ns in sonarqube argocd external-secrets; do
        kubectl delete pvc --all -n "$ns" --timeout=60s --ignore-not-found &>/dev/null || true
    done
    
    kubectl delete cm -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --ignore-not-found &>/dev/null || true
}

force_delete_ns() {
    local ns=$1
    kubectl delete namespace "$ns" --timeout=60s --ignore-not-found &>/dev/null && return
    
    if kubectl get namespace "$ns" &>/dev/null; then
        kubectl get namespace "$ns" -o json 2>/dev/null | \
            jq '.spec.finalizers = []' | \
            kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - &>/dev/null || true
        sleep 3
        kubectl delete namespace "$ns" --timeout=30s --ignore-not-found &>/dev/null || true
    fi
}

cleanup_namespaces() {
    log "Deleting namespaces..."
    for ns in argocd sonarqube external-secrets ingress-nginx; do
        force_delete_ns "$ns"
    done
}

cleanup_crds() {
    log "Cleaning up CRDs..."
    kubectl delete crd targetgroupbindings.elbv2.k8s.aws ingressclassparams.elbv2.k8s.aws --timeout=60s --ignore-not-found &>/dev/null || true
    kubectl delete crd secretstores.external-secrets.io externalsecrets.external-secrets.io \
        clustersecretstores.external-secrets.io clusterexternalsecrets.external-secrets.io --timeout=60s --ignore-not-found &>/dev/null || true
    kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --timeout=60s --ignore-not-found &>/dev/null || true
}

cleanup_webhooks() {
    log "Cleaning up webhooks..."
    kubectl delete validatingwebhookconfigurations ingress-nginx-admission aws-load-balancer-webhook argocd-application-controller --ignore-not-found &>/dev/null || true
    kubectl delete mutatingwebhookconfigurations ingress-nginx-admission aws-load-balancer-webhook --ignore-not-found &>/dev/null || true
}

cleanup_helm_secrets() {
    log "Cleaning up Helm secrets..."
    for ns in kube-system ingress-nginx external-secrets argocd sonarqube; do
        kubectl delete secret -n "$ns" -l owner=helm --ignore-not-found &>/dev/null || true
    done
}

verify() {
    log "Verifying cleanup..."
    echo ""
    helm list -A 2>/dev/null || log "✓ No Helm releases"
    kubectl get ns 2>/dev/null | grep -E 'argocd|sonarqube|external-secrets|ingress-nginx' || log "✓ Namespaces cleaned"
    kubectl get targetgroupbinding -A 2>/dev/null || log "✓ No TargetGroupBindings"
    kubectl get ingress -A 2>/dev/null || log "✓ No Ingress resources"
    kubectl get crd 2>/dev/null | grep -E 'external-secrets|argoproj|elbv2' || log "✓ CRDs cleaned"
    echo ""
    log "Cleanup complete!"
}

##############################################################################
# Main
##############################################################################

main() {
    log "Starting cluster cleanup..."
    confirm "${1:-}"
    setup_cluster
    cleanup_resources
    cleanup_helm
    cleanup_k8s
    cleanup_webhooks
    cleanup_namespaces
    cleanup_crds
    cleanup_helm_secrets
    verify
    log "Cluster ready for fresh deployment"
}

main "${1:-}"
