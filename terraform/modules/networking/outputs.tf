output "vpc_id" {
  value = var.vpc_id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

output "vpc_link_security_group_id" {
  value = length(aws_security_group.vpc_link) > 0 ? aws_security_group.vpc_link[0].id : null
}

output "api_gateway_endpoint" {
  value = length(aws_apigatewayv2_api.this) > 0 ? aws_apigatewayv2_api.this[0].api_endpoint : null
}

output "cognito_user_pool_id" {
  value = length(aws_cognito_user_pool.this) > 0 ? aws_cognito_user_pool.this[0].id : null
}

output "cognito_app_client_id" {
  value = length(aws_cognito_user_pool_client.this) > 0 ? aws_cognito_user_pool_client.this[0].id : null
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = length(aws_lb.nlb) > 0 ? aws_lb.nlb[0].arn : null
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = length(aws_lb.nlb) > 0 ? aws_lb.nlb[0].dns_name : null
}

output "nlb_target_group_arn" {
  description = "ARN of the NLB target group for ingress controller"
  value       = length(aws_lb_target_group.nlb) > 0 ? aws_lb_target_group.nlb[0].arn : null
}
