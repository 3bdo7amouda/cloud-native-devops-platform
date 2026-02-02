data "tls_certificate" "eks_oidc" {
  url = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_hostpath     = replace(var.oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = var.irsa_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = var.irsa_roles

  name               = "${var.cluster_name}-${each.key}-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = {
    for item in flatten([
      for k, v in var.irsa_roles : [
        for arn in v.policy_arns : {
          key        = "${k}|${arn}"
          role_key   = k
          policy_arn = arn
        }
      ]
    ]) : item.key => item
  }

  role       = aws_iam_role.irsa[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# cert-manager IRSA: Route 53 DNS-01 for Let's Encrypt (Pipeline 1)
data "aws_iam_policy_document" "cert_manager_assume" {
  count = var.enable_cert_manager_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager_irsa ? 1 : 0

  name               = "${var.cluster_name}-cert-manager-irsa"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "cert_manager_dns" {
  count = var.enable_cert_manager_irsa ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:GetChange"
    ]
    resources = var.cert_manager_hosted_zone_id != null ? ["arn:aws:route53:::hostedzone/${var.cert_manager_hosted_zone_id}"] : ["*"]
  }
}

resource "aws_iam_policy" "cert_manager_dns" {
  count = var.enable_cert_manager_irsa ? 1 : 0

  name   = "${var.cluster_name}-cert-manager-dns"
  policy = data.aws_iam_policy_document.cert_manager_dns[0].json
}

resource "aws_iam_role_policy_attachment" "cert_manager_dns" {
  count = var.enable_cert_manager_irsa ? 1 : 0

  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager_dns[0].arn
}
