output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
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
  value = module.iam.oidc_provider_arn
}

output "irsa_role_arns" {
  value = module.iam.irsa_role_arns
}
