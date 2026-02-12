variable "name_prefix" { type = string }

variable "vpc_id" {
  type        = string
  description = "ID of existing VPC to use"
}

variable "vpc_cidr" {
  type        = string
  default     = null
  description = "VPC CIDR (optional, only needed if creating new VPC)"
}

variable "azs" { type = list(string) }

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for NEW public subnets to create"
}

variable "private_subnet_cidrs" { type = list(string) }

variable "existing_public_subnet_id" {
  type        = string
  description = "ID of existing public subnet (contains Nexus/Agent)"
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

variable "cluster_name" { type = string }

variable "hosted_zone_id" {
  type        = string
  default     = null
  description = "Route53 hosted zone ID. Required if api_custom_domain is set."
}

variable "enable_api_gateway" {
  type    = bool
  default = true
}

variable "api_name" {
  type    = string
  default = null
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
