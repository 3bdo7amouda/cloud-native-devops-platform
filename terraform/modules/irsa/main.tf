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
