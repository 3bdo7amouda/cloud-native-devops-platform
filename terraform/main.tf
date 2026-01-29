module "vpc" {
  source = "./modules/vpc"

  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
  attach_ssm   = var.attach_ssm
  tags         = var.tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  cluster_role_arn          = module.iam.cluster_role_arn
  node_role_arn             = module.iam.node_role_arn
  private_subnet_ids        = module.vpc.private_subnet_ids 
  endpoint_public_access    = var.endpoint_public_access
  endpoint_private_access   = var.endpoint_private_access
  enabled_cluster_log_types = var.enabled_cluster_log_types
  log_retention_in_days     = var.log_retention_in_days
  node_desired              = var.node_desired
  node_min                  = var.node_min
  node_max                  = var.node_max
  instance_types            = var.instance_types
  capacity_type             = var.capacity_type
  tags                      = var.tags
}