data "aws_region" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

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
  igw_id                     = var.existing_igw_id != null ? data.aws_internet_gateway.existing[0].id : aws_internet_gateway.this[0].id
  enable_api_custom_domain   = var.enable_api_gateway && var.api_custom_domain != null && var.api_custom_domain != ""
  nexus_registry_domain      = var.nexus_registry_domain != null && var.nexus_registry_domain != "" ? var.nexus_registry_domain : (var.api_custom_domain != null && var.api_custom_domain != "" ? "nexus.${var.api_custom_domain}" : null)
  enable_nexus_registry_cert = var.hosted_zone_id != null && local.nexus_registry_domain != null && local.nexus_registry_domain != ""
  enable_nexus_registry_alb  = local.enable_nexus_registry_cert && var.nexus_registry_target_ip != null && var.nexus_registry_target_ip != ""
}

data "aws_subnet" "existing_public" {
  count = var.existing_public_subnet_id != null ? 1 : 0
  id    = var.existing_public_subnet_id
}

data "aws_route_table" "existing_public" {
  count = var.existing_public_route_table_id != null ? 1 : 0
  id    = var.existing_public_route_table_id
}

locals {
  existing_public_az = var.existing_public_subnet_id != null ? data.aws_subnet.existing_public[0].availability_zone : null
  public_subnet_azs = (
    var.existing_public_subnet_id != null &&
    length(var.public_subnet_cidrs) == 1 &&
    length(var.azs) > 1 &&
    contains(var.azs, local.existing_public_az)
  ) ? (
    [for az in var.azs : az if az != local.existing_public_az]
  ) : var.azs
  public_route_table_id = var.existing_public_route_table_id != null ? data.aws_route_table.existing_public[0].id : aws_route_table.public[0].id
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.public_subnet_azs[count.index % length(local.public_subnet_azs)]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-public-${local.public_subnet_azs[count.index % length(local.public_subnet_azs)]}" },
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = "1"
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
  count  = var.existing_public_route_table_id == null ? 1 : 0
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route" "public_inet" {
  count                  = var.existing_public_route_table_id == null ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.igw_id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = local.public_route_table_id
}

resource "aws_route_table_association" "existing_public" {
  count          = (var.manage_existing_public_route_association && var.existing_public_subnet_id != null) ? 1 : 0
  subnet_id      = data.aws_subnet.existing_public[0].id
  route_table_id = local.public_route_table_id
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
  count           = (var.enable_api_gateway && var.enable_cognito) ? 1 : 0
  name            = "${var.cluster_name}-client"
  user_pool_id    = aws_cognito_user_pool.this[0].id
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

resource "aws_acm_certificate" "api_custom_domain" {
  count             = local.enable_api_custom_domain ? 1 : 0
  domain_name       = var.api_custom_domain
  validation_method = "DNS"
  tags              = var.tags

  lifecycle { create_before_destroy = true }
}

locals {
  api_custom_domain_validation_options = local.enable_api_custom_domain ? tolist(aws_acm_certificate.api_custom_domain[0].domain_validation_options) : []
}

resource "aws_route53_record" "api_custom_domain_validation" {
  for_each = {
    for dvo in local.api_custom_domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api_custom_domain" {
  count                   = local.enable_api_custom_domain ? 1 : 0
  certificate_arn         = aws_acm_certificate.api_custom_domain[0].arn
  validation_record_fqdns = values(aws_route53_record.api_custom_domain_validation)[*].fqdn
}

resource "aws_apigatewayv2_domain_name" "api_custom_domain" {
  count       = local.enable_api_custom_domain ? 1 : 0
  domain_name = var.api_custom_domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api_custom_domain[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

resource "aws_apigatewayv2_api_mapping" "api_custom_domain" {
  count       = local.enable_api_custom_domain ? 1 : 0
  api_id      = aws_apigatewayv2_api.this[0].id
  domain_name = aws_apigatewayv2_domain_name.api_custom_domain[0].id
  stage       = aws_apigatewayv2_stage.this[0].name
}

resource "aws_route53_record" "api_custom_domain" {
  count   = local.enable_api_custom_domain ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.api_custom_domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api_custom_domain[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_custom_domain[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "nexus_registry" {
  count             = local.enable_nexus_registry_cert ? 1 : 0
  domain_name       = local.nexus_registry_domain
  validation_method = "DNS"
  tags              = var.tags

  lifecycle { create_before_destroy = true }
}

locals {
  nexus_registry_validation_options = local.enable_nexus_registry_cert ? tolist(aws_acm_certificate.nexus_registry[0].domain_validation_options) : []
}

resource "aws_route53_record" "nexus_registry_validation" {
  for_each = {
    for dvo in local.nexus_registry_validation_options : dvo.domain_name => dvo
  }

  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "nexus_registry" {
  count                   = local.enable_nexus_registry_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.nexus_registry[0].arn
  validation_record_fqdns = values(aws_route53_record.nexus_registry_validation)[*].fqdn
}

resource "aws_security_group" "nexus_registry_alb" {
  count = local.enable_nexus_registry_alb ? 1 : 0

  name        = "${var.name_prefix}-nexus-registry-alb-sg"
  description = "Security group for Nexus registry ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nexus-registry-alb-sg" })
}

resource "aws_lb" "nexus_registry" {
  count              = local.enable_nexus_registry_alb ? 1 : 0
  name               = substr("${var.name_prefix}-nexus-registry", 0, 32)
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nexus_registry_alb[0].id]
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-nexus-registry" })
}

resource "aws_lb_target_group" "nexus_registry" {
  count       = local.enable_nexus_registry_alb ? 1 : 0
  name        = substr("${var.name_prefix}-nexus-reg-tg", 0, 32)
  port        = var.nexus_registry_target_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/v2/"
    matcher             = "200,401"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nexus-registry-tg" })
}

resource "aws_lb_target_group_attachment" "nexus_registry" {
  count            = local.enable_nexus_registry_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.nexus_registry[0].arn
  target_id        = var.nexus_registry_target_ip
  port             = var.nexus_registry_target_port
}

resource "aws_lb_listener" "nexus_registry_https" {
  count             = local.enable_nexus_registry_alb ? 1 : 0
  load_balancer_arn = aws_lb.nexus_registry[0].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.nexus_registry[0].certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nexus_registry[0].arn
  }
}

resource "aws_route53_record" "nexus_registry_alias" {
  count   = local.enable_nexus_registry_alb ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = local.nexus_registry_domain
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.nexus_registry[0].dns_name
    zone_id                = aws_lb.nexus_registry[0].zone_id
    evaluate_target_health = false
  }
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
  integration_uri    = var.api_integration_uri != null && var.api_integration_uri != "" ? var.api_integration_uri : aws_lb_listener.nlb[0].arn

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
  target_type = "alb"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/healthz"
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
