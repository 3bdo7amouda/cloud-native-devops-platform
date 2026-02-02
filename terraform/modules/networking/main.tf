resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
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

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
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
  vpc_id = aws_vpc.this.id
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

# DNS baseline: Route 53 hosted zone (create if domain_name set; pre-steps may create zone and pass hosted_zone_id)
resource "aws_route53_zone" "this" {
  count   = var.domain_name != null ? 1 : 0
  name    = var.domain_name
  comment = "Managed by Terraform (Pipeline 1)"
  tags    = var.tags
}

locals {
  hosted_zone_id = coalesce(
    var.hosted_zone_id,
    try(aws_route53_zone.this[0].zone_id, null)
  )
}

resource "aws_cognito_user_pool" "this" {
  count = var.enable_cognito ? 1 : 0
  name  = coalesce(var.cognito_user_pool_name, "${var.cluster_name}-pool")
  tags  = var.tags
}

resource "aws_cognito_user_pool_client" "this" {
  count        = var.enable_cognito ? 1 : 0
  name         = "${var.cluster_name}-client"
  user_pool_id = var.enable_cognito ? aws_cognito_user_pool.this[0].id : ""

  generate_secret = false
}

resource "aws_apigatewayv2_api" "this" {
  name          = coalesce(var.api_name, "${var.cluster_name}-http-api")
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count           = var.enable_cognito ? 1 : 0
  api_id          = aws_apigatewayv2_api.this.id
  name            = "jwt"
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://${aws_cognito_user_pool.this[0].endpoint}"
    audience = [aws_cognito_user_pool_client.this[0].id]
  }
}

# VPC Link / NLB integration: set api_integration_uri when NLB exists (e.g. created later by ingress-nginx)
resource "aws_apigatewayv2_integration" "this" {
  count                  = var.api_integration_uri != null ? 1 : 0
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.api_integration_uri
  payload_format_version = "1.0"
}

# API Gateway routes: /api/* and /auth/* (Pipeline 1 - API only)
resource "aws_apigatewayv2_route" "api" {
  count = var.api_integration_uri != null ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.enable_cognito ? "JWT" : "NONE"
  authorizer_id      = var.enable_cognito ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_apigatewayv2_route" "auth" {
  count = var.api_integration_uri != null ? 1 : 0

  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.enable_cognito ? "JWT" : "NONE"
  authorizer_id      = var.enable_cognito ? aws_apigatewayv2_authorizer.jwt[0].id : null
}
