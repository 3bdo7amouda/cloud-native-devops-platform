# Infrastructure — Terraform

> **Stage 1** of the [Cloud-Native DevOps Platform](../README.md).

Terraform configuration for AWS: EKS, IAM, API Gateway HTTP API, Cognito, and Kubernetes addons deployed in an existing VPC. After provisioning, deploy the [Voting App with Helm](../helm-charts/README.md); application source is in [voting-app/](../voting-app/README.md).

---

## 📋 Infrastructure Details

### VPC Configuration
- **VPC ID:** `vpc-0e98d37ab3160b45f`
- **CIDR Block:** `172.30.0.0/16`
- **Region:** `us-east-1`
- **Availability Zones:** `us-east-1a`, `us-east-1b`

### Networking (networking module)
- **Public Subnets:** `172.30.1.0/24`, `172.30.2.0/24` (2 AZs)
- **Private Subnets:** `172.30.11.0/24`, `172.30.12.0/24` (2 AZs)
- **Internet Gateway** for public subnet internet access
- **NAT Gateway** with Elastic IP for private subnet internet access
- **Route tables** and associations
- **Subnet tags** for EKS load balancer discovery (`kubernetes.io/cluster/...`, `kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`)
- **API Gateway HTTP API** with default stage (`$default`)
- **Cognito** user pool and user pool client
- **JWT authorizer** (Cognito) on API Gateway
- **Integration + route** when `api_integration_uri` is set (proxy to NLB)

**No ACM, no Route53, no custom domain.** Public endpoint: `https://<api-id>.execute-api.<region>.amazonaws.com` — TLS handled by AWS.

### Security (IAM module)
- EKS **cluster IAM role**
- **Node group IAM role** (worker, CNI, ECR, optional SSM)

### Kubernetes (EKS module)
- **EKS cluster** with public/private endpoints
- **Managed node group** (scaling config, instance types)
- Addons: **vpc-cni**, **kube-proxy**, **coredns**
- CloudWatch log group for cluster logs

### IRSA (irsa module)
- **OIDC provider** for the EKS cluster (required for IRSA)
- **IRSA roles** (e.g. **EBS CSI** driver)
- **EBS CSI addon** (created in root, uses IRSA role)

---

## 📁 Structure

```
terraform/
├── main.tf                 # Orchestrates modules + EBS CSI addon
├── variables.tf            # Root variable declarations
├── outputs.tf              # Exposed outputs
├── providers.tf            # AWS provider
├── backend.tf              # S3 remote state
├── nonprod.tfvars          # Non-prod environment
└── modules/
    ├── networking/         # Subnets, IGW, NAT, API Gateway, Cognito
    ├── iam/                # EKS cluster + node roles
    ├── eks/                # EKS cluster, node group, addons (no EBS CSI)
    └── irsa/               # OIDC provider, IRSA roles (e.g. EBS CSI)
```

---

## 🚀 Quick Start

### Prerequisites
- Terraform >= 1.6.0
- AWS CLI >= 2.0
- kubectl (version aligned with EKS)
- AWS account with sufficient permissions
- Existing VPC: `vpc-0e98d37ab3160b45f`

### Step 1 — Initial Apply

Set **api_integration_uri = null** (default). Apply to create networking resources, EKS, API Gateway, Cognito, and IRSA.

```bash
cd terraform
terraform init
terraform plan -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

**Capture output:**
```bash
terraform output api_gateway_endpoint
# e.g. https://xxxxxxxx.execute-api.us-east-1.amazonaws.com
```

### Step 2 — Deploy ingress-nginx and get NLB DNS

- Deploy **ingress-nginx** (e.g. Helm or manifest) with Service type **LoadBalancer**.
- Confirm the AWS-created **NLB** and its DNS name (e.g. `k8s-xxxxx-xxxxx.elb.amazonaws.com`).
- Backend and ingress are **HTTP only** (port 80).

### Step 3 — Wire API Gateway to NLB

Set **api_integration_uri** to the NLB URL (HTTP):

```hcl
# e.g. in nonprod.tfvars or -var
api_integration_uri = "http://k8s-xxxxx-xxxxx.elb.amazonaws.com"
```

Then apply again:

```bash
terraform apply -var-file=nonprod.tfvars
```

**Final traffic flow:**  
Client → API Gateway (HTTPS) → JWT (Cognito) → NLB (HTTP) → ingress-nginx → Service (HTTP).

---

## 📝 Configuration

### Root Module Variables

**Required:**
- **vpc_id** — Existing VPC ID (`vpc-0e98d37ab3160b45f`)
- **cluster_name** — EKS and resource naming
- **azs** — Availability zones (e.g., `["us-east-1a", "us-east-1b"]`)
- **public_subnet_cidrs** — Public subnet CIDRs within VPC CIDR
- **private_subnet_cidrs** — Private subnet CIDRs within VPC CIDR

**Optional:**
- **vpc_cidr** — VPC CIDR for reference (default: `null`)
- **api_integration_uri** — `null` at first; then `http://<nlb-dns>` after NLB is ready
- **enable_cognito** — Enable Cognito + JWT (default `true`)
- **cognito_user_pool_name** — Optional; defaults to `{cluster_name}-pool`
- **api_name** — Optional; defaults to `{cluster_name}-http-api`
- **tags** — Resource tags

Plus EKS variables (cluster_version, node_*, instance_types, etc.) as in **variables.tf** and **nonprod.tfvars**.

---

## 📝 Networking Module Variables

| Variable | Description |
|----------|-------------|
| `vpc_id` | Existing VPC ID |
| `cluster_name` | Used for naming and tags |
| `api_name` | Optional; API name |
| `api_integration_uri` | Default `null`; set to `http://<nlb-dns>` after NLB exists |
| `enable_cognito` | Create Cognito pool + client and JWT authorizer |
| `cognito_user_pool_name` | Optional |
| `tags` | Resource tags |

Plus: `name_prefix`, `vpc_cidr`, `azs`, `public_subnet_cidrs`, `private_subnet_cidrs`.

---

## 📊 Outputs

```bash
terraform output
terraform output api_gateway_endpoint
terraform output -raw cluster_name
terraform output cluster_endpoint
```

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Kubernetes API endpoint |
| `cluster_ca` | Cluster CA (sensitive) |
| `oidc_issuer_url` | EKS OIDC issuer URL |
| `oidc_provider_arn` | IAM OIDC provider ARN |
| `irsa_role_arns` | Map of IRSA role ARNs (e.g. ebs_csi) |
| `api_gateway_endpoint` | API Gateway default HTTPS endpoint |
| `cognito_user_pool_id` | Cognito user pool ID |
| `cognito_app_client_id` | Cognito app client ID |

---

## 🔒 State Management

**Backend:** S3 with versioning and encryption (see **backend.tf**).

```bash
terraform state list
terraform refresh -var-file=nonprod.tfvars
terraform force-unlock <LOCK_ID>   # if state lock stuck
```

---

## 🐛 Troubleshooting

**Expired credentials**
```bash
rm -rf ~/.aws/cli/cache/*
export AWS_PROFILE=devops-role
aws sts get-caller-identity
```

**Subnet / resource conflicts**
```bash
terraform plan -destroy -var-file=nonprod.tfvars
terraform destroy -var-file=nonprod.tfvars
# Fix tfvars, then apply again
```

**Provider / init issues**
```bash
rm -rf .terraform/
terraform init
```

---

## 🗑️ Cleanup

```bash
terraform plan -destroy -var-file=nonprod.tfvars
terraform destroy -var-file=nonprod.tfvars
```

---

## ✅ Status

- [x] Using existing VPC (`vpc-0e98d37ab3160b45f`)
- [x] Public/private subnets, IGW, NAT, routes, EKS subnet tags
- [x] EKS cluster and managed node group
- [x] IAM: cluster role, node role
- [x] OIDC provider and IRSA (EBS CSI)
- [x] API Gateway HTTP API, default stage
- [x] Cognito user pool + client, JWT authorizer
- [x] Optional integration/route when `api_integration_uri` is set
- [x] No ACM, Route53, or cert-manager

---

## 🔜 Next Steps

- Deploy **ingress-nginx**, set **api_integration_uri**, then apply again.
- Deploy app: [Helm chart](../helm-charts/README.md) and [Voting App source](../voting-app/README.md).

---

## 📚 Documentation

- [Main README](../README.md) — Platform guide and structure
- [Helm chart](../helm-charts/README.md) — Deploy Voting App on EKS
- [Voting App source](../voting-app/README.md) — vote, result, worker build context

---

**Last Updated:** February 3, 2026 | **Terraform:** >= 1.6.0
