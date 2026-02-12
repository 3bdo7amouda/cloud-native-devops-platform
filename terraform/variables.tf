variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "ID of existing VPC to use"
}

variable "vpc_cidr" {
  type        = string
  default     = null
  description = "VPC CIDR (optional, only for reference)"
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for NEW public subnets to create"
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "existing_public_subnet_id" {
  type        = string
  description = "ID of existing public subnet (172.30.2.0/24 with Nexus/Agent)"
  default     = null
}

variable "manage_existing_public_route_association" {
  type        = bool
  description = "Whether Terraform should manage the route table association for the existing public subnet"
  default     = true
}

variable "existing_igw_id" {
  type        = string
  description = "ID of existing Internet Gateway"
  default     = null
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

variable "hosted_zone_id" {
  type        = string
  default     = null
  description = "Route53 hosted zone ID. Required if api_custom_domain is set."
}

variable "api_custom_domain" {
  type        = string
  default     = null
  description = "Custom domain for API Gateway (e.g., api.example.com). When set, ACM cert + Route53 records are created."

  validation {
    condition     = var.api_custom_domain == null || var.api_custom_domain == "" || !var.enable_api_gateway || var.hosted_zone_id != null
    error_message = "api_custom_domain requires hosted_zone_id to be set for Route53 validation and alias records."
  }
}

variable "nexus_registry_domain" {
  type        = string
  default     = null
  description = "Custom domain for Nexus Docker registry (e.g., nexus.example.com). When set, ACM cert + Route53 validation are created."

  validation {
    condition     = var.nexus_registry_domain == null || var.nexus_registry_domain == "" || var.hosted_zone_id != null
    error_message = "nexus_registry_domain requires hosted_zone_id to be set for Route53 validation."
  }
}

variable "nexus_registry_target_ip" {
  type        = string
  default     = null
  description = "Private IP of the Nexus registry target (EC2) for the ALB target group"
}

variable "nexus_registry_target_port" {
  type        = number
  default     = 5000
  description = "Port of the Nexus registry target (default 5000)"
}

variable "enable_api_gateway" {
  type    = bool
  default = true
}

variable "cluster_access_entries" {
  description = "Map of access entries to add to the cluster"
  type = map(object({
    principal_arn = string
    policy_associations = map(object({
      policy_arn = string
      access_scope = object({
        type = string
      })
    }))
  }))
  default = {}
}
