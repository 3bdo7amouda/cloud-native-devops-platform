resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_security_group_rule" "cluster_ingress_agent_subnet" {
  description       = "Allow Azure DevOps agent subnet to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["172.30.2.0/24"]
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false  
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [aws_cloudwatch_log_group.this]
  tags       = var.tags
}

resource "aws_eks_access_entry" "this" {
  for_each = var.cluster_access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "this" {
  for_each = merge([
    for entry_key, entry in var.cluster_access_entries : {
      for policy_key, policy in entry.policy_associations :
      "${entry_key}-${policy_key}" => {
        principal_arn = entry.principal_arn
        policy_arn    = policy.policy_arn
        access_scope  = policy.access_scope
      }
    }
  ]...)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type = each.value.access_scope.type
  }

  depends_on = [aws_eks_access_entry.this]
}

resource "aws_eks_node_group" "platform" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-platform-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired
    max_size     = var.node_max
    min_size     = var.node_min
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  labels = {
    role     = "platform"
    workload = "system"
  }

  dynamic "launch_template" {
    for_each = local.use_insecure_registry ? [1] : []
    content {
      id      = aws_launch_template.platform[0].id
      version = aws_launch_template.platform[0].latest_version
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-platform-nodes"
      Role = "platform-tools"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [aws_eks_cluster.this]
}

locals {
  use_insecure_registry = var.insecure_registry_hostport != null && var.insecure_registry_hostport != ""
}

resource "aws_launch_template" "platform" {
  count       = local.use_insecure_registry ? 1 : 0
  name_prefix = "${var.cluster_name}-platform-ng-"

  user_data = base64encode(<<EOF
#!/bin/bash
set -euo pipefail

/etc/eks/bootstrap.sh '${var.cluster_name}'

REGISTRY="${var.insecure_registry_hostport}"
REGISTRY_DIR="/etc/containerd/certs.d/$${REGISTRY}"

mkdir -p "$${REGISTRY_DIR}"
cat <<HOSTS > "$${REGISTRY_DIR}/hosts.toml"
server = "http://$${REGISTRY}"

[host."http://$${REGISTRY}"]
  capabilities = ["pull", "resolve"]
HOSTS

if grep -qE '^[[:space:]]*config_path[[:space:]]*=' /etc/containerd/config.toml; then
  sed -i 's|^[[:space:]]*config_path[[:space:]]*=.*|  config_path = "/etc/containerd/certs.d"|' /etc/containerd/config.toml
else
  cat <<CFG >> /etc/containerd/config.toml

[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
CFG
fi

systemctl restart containerd
systemctl restart kubelet
EOF
  )
}

resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_addons ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_addons ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_addons ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.platform]
}

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_addons ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  service_account_role_arn = var.ebs_csi_service_account_role_arn

  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}
