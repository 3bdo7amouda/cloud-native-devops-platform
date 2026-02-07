#!/bin/bash

##############################################################################
# Kubernetes Cluster Full Cleanup Script
# Description: Removes all platform tools and resources from EKS cluster
# Usage: ./cleanup-cluster.sh [--confirm]
##############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

confirm_action() {
    if [[ "$1" != "--confirm" ]]; then
        log_warning "This will DELETE all platform resources from the cluster!"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Cleanup cancelled."
            exit 0
        fi
    fi
}

##############################################################################
# Setup Functions
##############################################################################

check_aws_credentials() {
    print_header "Validating AWS credentials"
    
    log_info "Checking AWS authentication..."
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials are not configured or have expired"
        log_error "Please run: aws configure"
        log_error "Or set: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"
        exit 1
    fi
    
    CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
    ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')
    USER_ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn')
    
    log_success "Authenticated as: $USER_ARN"
    log_info "Account ID: $ACCOUNT_ID"
}

setup_cluster_connection() {
    print_header "Setting up cluster connection"
    
    if [[ -z "$CLUSTER_NAME" ]]; then
        log_info "Auto-detecting cluster name..."
        CLUSTER_NAME=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters[0]' --output text)
        
        if [[ -z "$CLUSTER_NAME" || "$CLUSTER_NAME" == "None" ]]; then
            log_error "No EKS cluster found in region $AWS_REGION"
            exit 1
        fi
    fi
    
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Region: $AWS_REGION"
    
    log_info "Updating kubeconfig with fresh credentials..."
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --alias "$CLUSTER_NAME"
    
    log_info "Verifying cluster connection..."
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Failed to connect to cluster. Possible issues:"
        log_error "1. AWS credentials don't have EKS permissions"
        log_error "2. Cluster security group rules are blocking access"
        log_error "3. IAM role/user not mapped in aws-auth ConfigMap"
        
        log_info "Attempting to diagnose..."
        kubectl cluster-info 2>&1 || true
        exit 1
    fi
    
    kubectl get nodes -o wide || log_warning "Could not list nodes (permissions issue)"
    
    log_success "Cluster connection established"
}

##############################################################################
# Cleanup Functions
##############################################################################

cleanup_helm_releases() {
    print_header "Cleaning up Helm releases"
    
    log_info "Listing current Helm releases..."
    helm list -A || true
    
    # Uninstall platform tools in reverse order
    log_info "Uninstalling SonarQube..."
    helm uninstall sonarqube -n sonarqube --wait --timeout 5m 2>/dev/null || log_warning "SonarQube not found"
    
    log_info "Uninstalling Argo CD..."
    helm uninstall argocd -n argocd --wait --timeout 5m 2>/dev/null || log_warning "Argo CD not found"
    
    log_info "Uninstalling External Secrets Operator..."
    helm uninstall external-secrets -n external-secrets --wait --timeout 5m 2>/dev/null || log_warning "External Secrets not found"
    
    log_info "Uninstalling NGINX Ingress Controller..."
    helm uninstall ingress-nginx -n ingress-nginx --wait --timeout 5m 2>/dev/null || log_warning "NGINX Ingress not found"
    
    log_info "Uninstalling AWS Load Balancer Controller..."
    helm uninstall aws-load-balancer-controller -n kube-system --wait --timeout 5m 2>/dev/null || log_warning "AWS LBC not found"
    
    log_success "Helm releases cleanup complete"
}

cleanup_kubernetes_resources() {
    print_header "Cleaning up Kubernetes resources"
    
    # Delete TargetGroupBindings
    log_info "Deleting TargetGroupBindings..."
    kubectl delete targetgroupbinding --all -n ingress-nginx --ignore-not-found=true --timeout=60s 2>/dev/null || true
    
    # Delete Ingress resources
    log_info "Deleting Ingress resources..."
    kubectl delete ingress --all -n argocd --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete ingress --all -n sonarqube --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete ingress --all -A --ignore-not-found=true --timeout=60s 2>/dev/null || true
    
    # Delete ServiceAccounts
    log_info "Deleting AWS LBC ServiceAccount..."
    kubectl delete sa aws-load-balancer-controller -n kube-system --ignore-not-found=true 2>/dev/null || true
    
    # Delete PVCs (to prevent dangling volumes)
    log_info "Deleting PersistentVolumeClaims..."
    kubectl delete pvc --all -n sonarqube --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete pvc --all -n argocd --ignore-not-found=true --timeout=60s 2>/dev/null || true
    
    log_success "Kubernetes resources cleanup complete"
}

cleanup_namespaces() {
    print_header "Cleaning up namespaces"
    
    log_info "Deleting platform namespaces..."
    
    for ns in sonarqube argocd external-secrets ingress-nginx; do
        log_info "Deleting namespace: $ns"
        kubectl delete namespace "$ns" --ignore-not-found=true --timeout=120s 2>/dev/null || {
            log_warning "Namespace $ns stuck, removing finalizers..."
            kubectl get namespace "$ns" -o json 2>/dev/null | \
                jq '.spec.finalizers = []' | \
                kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
        }
    done
    
    log_success "Namespaces cleanup complete"
}

cleanup_crds() {
    print_header "Cleaning up Custom Resource Definitions"
    
    log_info "Removing finalizers from stuck TargetGroupBindings..."
    for tgb in $(kubectl get targetgroupbinding -A -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' 2>/dev/null); do
        NS=$(echo "$tgb" | cut -d',' -f1)
        NAME=$(echo "$tgb" | cut -d',' -f2)
        log_info "Patching TGB: $NS/$NAME"
        kubectl patch targetgroupbinding "$NAME" -n "$NS" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    done
    
    log_info "Deleting External Secrets CRDs..."
    kubectl delete crd secretstores.external-secrets.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete crd externalsecrets.external-secrets.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete crd clustersecretstores.external-secrets.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete crd clusterexternalsecrets.external-secrets.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    
    log_info "Deleting Argo CD CRDs..."
    kubectl delete crd applications.argoproj.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    kubectl delete crd appprojects.argoproj.io --ignore-not-found=true --timeout=60s 2>/dev/null || true
    
    log_success "CRD cleanup complete"
}

cleanup_helm_secrets() {
    print_header "Cleaning up stuck Helm secrets"
    
    log_info "Deleting Helm release secrets..."
    kubectl delete secret -n kube-system -l owner=helm --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret -n ingress-nginx -l owner=helm --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret -n external-secrets -l owner=helm --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret -n argocd -l owner=helm --ignore-not-found=true 2>/dev/null || true
    kubectl delete secret -n sonarqube -l owner=helm --ignore-not-found=true 2>/dev/null || true
    
    log_success "Helm secrets cleanup complete"
}

verify_cleanup() {
    print_header "Verifying cleanup status"
    
    echo ""
    log_info "Remaining Helm releases:"
    helm list -A || log_success "No Helm releases found"
    
    echo ""
    log_info "Remaining platform namespaces:"
    kubectl get ns 2>/dev/null | grep -E 'argocd|sonarqube|external-secrets|ingress-nginx' || log_success "All platform namespaces cleaned"
    
    echo ""
    log_info "Remaining TargetGroupBindings:"
    kubectl get targetgroupbinding -A 2>/dev/null || log_success "No TargetGroupBindings found"
    
    echo ""
    log_info "Remaining Ingress resources:"
    kubectl get ingress -A 2>/dev/null || log_success "No Ingress resources found"
    
    echo ""
    log_info "Remaining platform CRDs:"
    kubectl get crd 2>/dev/null | grep -E 'external-secrets|argoproj|elbv2' || log_success "No platform CRDs found"
    
    echo ""
    log_success "Cleanup verification complete!"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "Kubernetes Cluster Full Cleanup"
    
    # Confirm action
    confirm_action "${1:-}"
    
    # Validate AWS credentials first
    check_aws_credentials
    
    # Setup cluster connection
    setup_cluster_connection
    
    # Execute cleanup steps
    cleanup_helm_releases
    cleanup_kubernetes_resources
    cleanup_namespaces
    cleanup_crds
    cleanup_helm_secrets
    
    # Verify
    verify_cleanup
    
    print_header "Cleanup Complete!"
    log_success "All platform resources have been removed from the cluster"
    log_info "The cluster is now ready for a fresh deployment"
}

# Run main function
main "${1:-}"
