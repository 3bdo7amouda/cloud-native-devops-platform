variable "cluster_name" {
  type = string
}

variable "attach_ssm" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "oidc_issuer_url" {
  type    = string
}

variable "irsa_roles" {
  type = map(object({
    namespace            = string
    service_account_name = string
    policy_arns          = list(string)
  }))
  default = {}
}
