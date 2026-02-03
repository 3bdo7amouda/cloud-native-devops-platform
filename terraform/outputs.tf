output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_issuer_url" {
  value = module.eks.oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.irsa.oidc_provider_arn
}

output "irsa_role_arns" {
  value = module.irsa.irsa_role_arns
}

output "api_gateway_endpoint" {
  value = module.vpc.api_gateway_endpoint
}

output "cognito_user_pool_id" {
  value = module.vpc.cognito_user_pool_id
}

output "cognito_app_client_id" {
  value = module.vpc.cognito_app_client_id
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID (passthrough from input)"
  value       = var.hosted_zone_id
}
