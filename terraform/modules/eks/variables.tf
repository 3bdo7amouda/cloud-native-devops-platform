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

variable "tags" {
  type    = map(string)
  default = {}
}