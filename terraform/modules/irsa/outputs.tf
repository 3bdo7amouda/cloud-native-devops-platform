output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "irsa_role_arns" {
  value = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "cert_manager_irsa_role_arn" {
  value = var.enable_cert_manager_irsa ? aws_iam_role.cert_manager[0].arn : null
}
