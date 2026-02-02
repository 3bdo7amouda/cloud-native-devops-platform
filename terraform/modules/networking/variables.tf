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

variable "api_name" {
  type    = string
  default = null
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

variable "domain_name" {
  type    = string
  default = null
}

variable "hosted_zone_id" {
  type    = string
  default = null
}
