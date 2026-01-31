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
