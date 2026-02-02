variable "cluster_name" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "irsa_roles" {
  type = map(object({
    namespace            = string
    service_account_name = string
    policy_arns          = list(string)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

# cert-manager IRSA: Route 53 DNS-01 (Pipeline 1)
variable "enable_cert_manager_irsa" {
  type    = bool
  default = true
}

variable "cert_manager_hosted_zone_id" {
  type    = string
  default = null
}
