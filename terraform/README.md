# Infrastructure — Terraform

> **Stage 1** of the [Cloud-Native DevOps Platform](../README.md).

Terraform configuration for AWS: VPC, EKS cluster, IAM roles, and Kubernetes addons. After provisioning, deploy the [Voting App with Helm](../helm/README.md); application source is in [voting-app/](../voting-app/README.md).

---

## 📋 What Gets Deployed

### Networking (VPC Module)
- VPC with public/private subnets across 2 AZs
- Internet Gateway + NAT Gateway
- Route tables with proper associations
- Kubernetes subnet tags for load balancers

### Security (IAM Module)
- EKS cluster IAM role
- Node group IAM role with required policies
- SSM access for node debugging

### Kubernetes (EKS Module)
- EKS cluster (v1.35) with public/private endpoints
- Managed node group (auto-scaling, latest Amazon Linux 2)
- Essential addons: vpc-cni, kube-proxy, coredns, ebs-csi-driver
- CloudWatch logging enabled

---

## 📁 Structure

```
terraform/
├── main.tf                 # Orchestrates all modules
├── variables.tf            # Variable declarations
├── outputs.tf              # Exposed outputs
├── providers.tf            # AWS provider config
├── backend.tf              # S3 remote state
├── prod.tfvars             # Prod environment
├── (nonprod via variables / tfvars)
└── modules/
    ├── vpc/                # Networking resources
    ├── iam/                # IAM roles & policies
    └── eks/                # EKS cluster & nodes
```

---

## 🔧 Prerequisites

- Terraform >= 1.6.0
- AWS CLI >= 2.0
- kubectl >= 1.35
- AWS account with admin access

---

## 🚀 Quick Start

### 1. Setup AWS Credentials

Create permanent IAM user credentials and configure AWS CLI:

```bash
# Configure credentials
nano ~/.aws/credentials
```

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

```bash
# Configure role assumption
nano ~/.aws/config
```

```ini
[default]
region = us-east-1

[profile devops-role]
role_arn = arn:aws:iam::430118836758:role/terraform-deploy-role
source_profile = default
region = us-east-1
```

```bash
# Set profile permanently
echo 'export AWS_PROFILE=devops-role' >> ~/.bashrc
source ~/.bashrc
```

**Verify:**
```bash
aws sts get-caller-identity
# Should show the assumed role ARN
```

---

### 2. Create S3 Backend (One-time)

```bash
BUCKET="cloud-native-devops-platform-terraform-bucket"

# Create bucket with versioning and encryption
aws s3api create-bucket --bucket $BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

---

### 3. Deploy Infrastructure

From repository root, navigate to **terraform/**:

```bash
cd cloud-native-devops-platform/terraform

# Initialize
terraform init

# Preview changes
terraform plan -var-file=prod.tfvars
# or use your nonprod tfvars

# Deploy
terraform apply -var-file=prod.tfvars
```

---

### 4. Access EKS Cluster

```bash
# Configure kubectl (use cluster name from your tfvars/outputs)
aws eks update-kubeconfig \
  --name nonprod-eks \
  --region us-east-1

# Verify
kubectl get nodes
kubectl get pods -A
```

Next: build images from [voting-app/](../voting-app/README.md) and deploy with [helm/](../helm/README.md).

---

## 📝 Configuration

Use **prod.tfvars** (or your own tfvars) for environment-specific variables. See **variables.tf** for all options.

---

## 📊 Outputs

```bash
# View all outputs
terraform output

# Common outputs
terraform output vpc_id
terraform output cluster_endpoint
terraform output -raw cluster_name
```

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC identifier |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Kubernetes API endpoint |
| `oidc_issuer_url` | For IAM roles for service accounts |

---

## 🔒 State Management

**Backend:** S3 with encryption and versioning

**Common operations:**
```bash
terraform state list
terraform refresh -var-file=prod.tfvars
terraform force-unlock <LOCK_ID>   # if state lock stuck
```

---

## 🐛 Troubleshooting

### Expired Credentials
```bash
rm -rf ~/.aws/cli/cache/*
export AWS_PROFILE=devops-role
aws sts get-caller-identity
```

### Subnet / resource conflicts
```bash
terraform destroy -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

### Provider issues
```bash
rm -rf .terraform/
terraform init
```

---

## 🗑️ Cleanup

```bash
terraform plan -destroy -var-file=prod.tfvars
terraform destroy -var-file=prod.tfvars
```

---

## ✅ Status

- [x] VPC with networking
- [x] IAM roles for EKS
- [x] EKS cluster (1.35)
- [x] Managed node groups
- [x] EKS addons (CNI, DNS, proxy, storage)
- [x] Remote state in S3
- [x] Multi-environment support

---

## 🔜 Next Steps

- **Stage 2:** NGINX Ingress, cert-manager, metrics-server
- **Stage 3:** Nexus, SonarQube, persistent storage
- **Deploy app:** [Helm chart](../helm/README.md) and [Voting App source](../voting-app/README.md)

---

## 📚 Documentation

- [Main README](../README.md) — Platform guide and structure
- [Helm chart](../helm/README.md) — Deploy Voting App on EKS
- [Voting App source](../voting-app/README.md) — vote, result, worker build context

---

**Last Updated:** January 29, 2026 | **Terraform:** >= 1.6.0 | **Kubernetes:** 1.35
