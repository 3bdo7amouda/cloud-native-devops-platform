resource "aws_internet_gateway" "this" {
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-public-${var.azs[count.index]}" },
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                   = "1"
    }
  )

  lifecycle { create_before_destroy = true }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-private-${var.azs[count.index]}" },
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = "1"
    }
  )

  lifecycle { create_before_destroy = true }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(var.tags, { Name = "${var.name_prefix}-nat" })
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-private" })
}

resource "aws_route" "private_inet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Route53 (EXISTING ONLY)
locals {
  hosted_zone_id = var.hosted_zone_id
}

# Cognito (Pipeline 1)
resource "aws_cognito_user_pool" "this" {
  count = (var.enable_api_gateway && var.enable_cognito) ? 1 : 0
  name  = coalesce(var.cognito_user_pool_name, "${var.cluster_name}-pool")
  tags  = var.tags
}

resource "aws_cognito_user_pool_client" "this" {
  count        = (var.enable_api_gateway && var.enable_cognito) ? 1 : 0
  name         = "${var.cluster_name}-client"
  user_pool_id = aws_cognito_user_pool.this[0].id
  generate_secret = false
}

# API Gateway (Pipeline 1)
resource "aws_apigatewayv2_api" "this" {
  count         = var.enable_api_gateway ? 1 : 0
  name          = coalesce(var.api_name, "${var.cluster_name}-http-api")
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  count       = var.enable_api_gateway ? 1 : 0
  api_id      = aws_apigatewayv2_api.this[0].id
  name        = "$default"
  auto_deploy = true
}

# VPC Link prepared for later NLB integration (Pipeline 2 provides the NLB)
resource "aws_apigatewayv2_vpc_link" "this" {
  count = var.enable_api_gateway ? 1 : 0

  name               = "${var.cluster_name}-vpc-link"
  subnet_ids         = [for s in aws_subnet.private : s.id]
  security_group_ids = []

  tags = var.tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count            = (var.enable_api_gateway && var.enable_cognito) ? 1 : 0
  api_id           = aws_apigatewayv2_api.this[0].id
  name             = "jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://${aws_cognito_user_pool.this[0].endpoint}"
    audience = [aws_cognito_user_pool_client.this[0].id]
  }
}

# Integration + routes are created ONLY when NLB listener ARN exists
resource "aws_apigatewayv2_integration" "this" {
  count = (var.enable_api_gateway && var.api_integration_uri != null) ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this[0].id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.api_integration_uri
  payload_format_version = "1.0"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.this[0].id
}

resource "aws_apigatewayv2_route" "api" {
  count = (var.enable_api_gateway && var.api_integration_uri != null) ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.enable_cognito ? "JWT" : "NONE"
  authorizer_id      = var.enable_cognito ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_apigatewayv2_route" "auth" {
  count = (var.enable_api_gateway && var.api_integration_uri != null) ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "ANY /auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.enable_cognito ? "JWT" : "NONE"
  authorizer_id      = var.enable_cognito ? aws_apigatewayv2_authorizer.jwt[0].id : null
}