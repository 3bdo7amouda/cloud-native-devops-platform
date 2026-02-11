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

output "api_custom_domain" {
  value = module.vpc.api_custom_domain
}

output "api_custom_domain_target" {
  value = module.vpc.api_custom_domain_target
}

output "nexus_registry_domain" {
  description = "Nexus registry custom domain (if enabled)"
  value       = module.vpc.nexus_registry_domain
}

output "nexus_registry_certificate_arn" {
  description = "ACM certificate ARN for the Nexus registry domain (if enabled)"
  value       = module.vpc.nexus_registry_certificate_arn
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

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = module.vpc.nlb_arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = module.vpc.nlb_dns_name
}

output "nlb_target_group_arn" {
  description = "ARN of the NLB target group for ingress controller"
  value       = module.vpc.nlb_target_group_arn
}

output "node_group_id" {
  description = "ID of the platform node group"
  value       = module.eks.node_group_id
}

output "node_group_status" {
  description = "Status of the platform node group"
  value       = module.eks.node_group_status
}

output "fargate_profile_id" {
  description = "ID of the voting-app Fargate Profile"
  value       = module.eks.fargate_profile_id
}
