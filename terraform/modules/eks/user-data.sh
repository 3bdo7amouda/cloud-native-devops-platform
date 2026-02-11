MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -euo pipefail

/etc/eks/bootstrap.sh '${cluster_name}'

REGISTRY="${insecure_registry_hostport}"
REGISTRY_DIR="/etc/containerd/certs.d/$REGISTRY"

mkdir -p "$REGISTRY_DIR"
cat <<HOSTS > "$REGISTRY_DIR/hosts.toml"
server = "http://$REGISTRY"

[host."http://$REGISTRY"]
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

--==BOUNDARY==--
