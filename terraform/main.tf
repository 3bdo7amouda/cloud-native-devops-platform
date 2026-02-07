module "vpc" {
  source = "./modules/networking"
  name_prefix           = var.name_prefix
  vpc_id                = var.vpc_id
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  cluster_name          = var.cluster_name
  existing_public_subnet_id = var.existing_public_subnet_id
  existing_igw_id           = var.existing_igw_id
  hosted_zone_id        = var.hosted_zone_id
  enable_api_gateway    = var.enable_api_gateway
  api_name              = var.api_name
  api_integration_uri   = var.api_integration_uri
  enable_cognito        = var.enable_cognito
  cognito_user_pool_name = var.cognito_user_pool_name
  tags = var.tags
}

module "iam" {
  source = "./modules/iam"
  cluster_name = var.cluster_name
  tags         = var.tags
}

module "eks" {
  source = "./modules/eks"
  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_role_arn               = module.iam.cluster_role_arn
  node_role_arn                  = module.iam.node_role_arn
  fargate_pod_execution_role_arn = module.iam.fargate_pod_execution_role_arn
  private_subnet_ids             = module.vpc.private_subnet_ids
  endpoint_public_access         = var.endpoint_public_access
  endpoint_private_access        = var.endpoint_private_access
  enabled_cluster_log_types      = var.enabled_cluster_log_types
  log_retention_in_days          = var.log_retention_in_days
  node_desired                   = var.node_desired
  node_min                       = var.node_min
  node_max                       = var.node_max
  instance_types                 = var.instance_types
  capacity_type                  = var.capacity_type
  cluster_access_entries         = var.cluster_access_entries
  tags                           = var.tags
}

module "irsa" {
  source = "./modules/irsa"
  cluster_name    = var.cluster_name
  oidc_issuer_url = module.eks.oidc_issuer_url
  irsa_roles = {
    ebs_csi = {
      namespace            = "kube-system"
      service_account_name = "ebs-csi-controller-sa"
      policy_arns          = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
    }
    nginx_ingress = {
      namespace            = "ingress-nginx"
      service_account_name = "ingress-nginx"
      policy_arns          = ["arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"]
    }
  }
  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.irsa.irsa_role_arns["ebs_csi"]
  resolve_conflicts_on_update = "OVERWRITE"
  tags                       = var.tags
}
