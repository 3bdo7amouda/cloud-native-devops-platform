output "vpc_id" {
  value = data.aws_vpc.existing.id
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

output "hosted_zone_id" {
  value = local.hosted_zone_id
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
