variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
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
  type        = number
  default     = 2
  description = "Desired number of platform nodes"
}

variable "node_min" {
  type        = number
  default     = 1
  description = "Minimum number of platform nodes"
}

variable "node_max" {
  type        = number
  default     = 3
  description = "Maximum number of platform nodes"
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Instance types for platform nodes"
}

variable "capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "Capacity type for platform nodes (ON_DEMAND or SPOT)"
}

variable "tags" {
  type    = map(string)
  default = {}
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

variable "enable_addons" {
  description = "Whether the EKS module should manage standard EKS addons"
  type        = bool
  default     = true
}

variable "ebs_csi_service_account_role_arn" {
  description = "IRSA role ARN for the aws-ebs-csi-driver add-on"
  type        = string
  default     = null
}
