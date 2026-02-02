variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "endpoint_private_access" {
  type    = bool
  default = false
}

variable "enabled_cluster_log_types" {
  type    = list(string)
  default = ["api", "audit"]
}

variable "log_retention_in_days" {
  type    = number
  default = 7
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "node_min" {
  type    = number
  default = 1
}

variable "node_max" {
  type    = number
  default = 3
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "attach_ssm" {
  type    = bool
  default = true
}

variable "api_name" {
  type    = string
  default = null
}

# Set when NLB exists (e.g. after ingress-nginx); prepared for VPC Link / NLB integration (Pipeline 1)
variable "api_integration_uri" {
  type    = string
  default = null
}

variable "enable_cognito" {
  type    = bool
  default = true
}

variable "cognito_user_pool_name" {
  type    = string
  default = null
}

# DNS baseline (Pipeline 1): create zone if domain_name set, else pass existing hosted_zone_id
variable "domain_name" {
  type    = string
  default = null
}

variable "hosted_zone_id" {
  type    = string
  default = null
}

# cert-manager IRSA (Pipeline 1)
variable "enable_cert_manager_irsa" {
  type    = bool
  default = true
}

variable "cert_manager_hosted_zone_id" {
  type    = string
  default = null
}