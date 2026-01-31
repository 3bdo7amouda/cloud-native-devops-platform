output "vpc_id" {
  value = aws_vpc.this.id
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

output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "api_domain_name" {
  value = aws_apigatewayv2_domain_name.this.domain_name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this[0].id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.this[0].id
}
