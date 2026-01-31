output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "irsa_role_arns" {
  value = { for k, v in aws_iam_role.irsa : k => v.arn }
}
