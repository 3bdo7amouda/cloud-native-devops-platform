data "aws_region" "current" {}

data "aws_internet_gateway" "existing" {
  count = var.existing_igw_id != null ? 1 : 0

  filter {
    name   = "internet-gateway-id"
    values = [var.existing_igw_id]
  }
}

resource "aws_internet_gateway" "this" {
  count  = var.existing_igw_id == null ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

locals {
  igw_id = var.existing_igw_id != null ? data.aws_internet_gateway.existing[0].id : aws_internet_gateway.this[0].id
}

data "aws_subnet" "existing_public" {
  count = var.existing_public_subnet_id != null ? 1 : 0
  id    = var.existing_public_subnet_id
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-public-${var.azs[count.index % length(var.azs)]}" },
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                   = "1"
    }
  )

  lifecycle { create_before_destroy = true }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-private-${var.azs[count.index % length(var.azs)]}" },
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
  gateway_id             = local.igw_id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "existing_public" {
  count          = var.existing_public_subnet_id != null ? 1 : 0
  subnet_id      = data.aws_subnet.existing_public[0].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_route_table_association.public]
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
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "vpc_link" {
  count = var.enable_api_gateway ? 1 : 0

  name        = "${var.name_prefix}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc-link-sg" })
}

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

resource "aws_apigatewayv2_vpc_link" "this" {
  count = var.enable_api_gateway ? 1 : 0

  name               = "${var.cluster_name}-vpc-link"
  subnet_ids         = [for s in aws_subnet.private : s.id]
  security_group_ids = [aws_security_group.vpc_link[0].id]

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

resource "aws_apigatewayv2_integration" "this" {
  count = var.enable_api_gateway ? 1 : 0
  
  api_id             = aws_apigatewayv2_api.this[0].id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.nlb[0].arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.this[0].id
}

resource "aws_apigatewayv2_route" "api" {
  count = var.enable_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = var.enable_cognito ? "JWT" : "NONE"
  authorizer_id      = var.enable_cognito ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_apigatewayv2_route" "auth" {
  count = var.enable_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "ANY /auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = "NONE"
  authorizer_id      = null
}

resource "aws_apigatewayv2_route" "default" {
  count = var.enable_api_gateway ? 1 : 0

  api_id    = aws_apigatewayv2_api.this[0].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.this[0].id}"

  authorization_type = "NONE"
  authorizer_id      = null
}

resource "aws_lb" "nlb" {
  count              = var.enable_api_gateway ? 1 : 0
  name               = "${var.name_prefix}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-nlb" })
}

resource "aws_lb_target_group" "nlb" {
  count       = var.enable_api_gateway ? 1 : 0
  name        = "${var.name_prefix}-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  deregistration_delay = 30

  tags = merge(var.tags, { Name = "${var.name_prefix}-nlb-tg" })
}

resource "aws_lb_listener" "nlb" {
  count             = var.enable_api_gateway ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[0].arn
  }

  tags = var.tags
}