# Infrastructure Provisioning - Terraform

> **Stage 1** of Cloud-Native DevOps Platform

Terraform configuration for AWS infrastructure: VPC, EKS cluster, IAM roles, and Kubernetes addons.

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
├── nonprod.tfvars          # Non-prod environment
├── prod.tfvars             # Prod environment
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

```bash
cd ~/cloud-native-devops-platform/terraform

# Initialize
terraform init

# Preview changes
terraform plan -var-file=nonprod.tfvars

# Deploy
terraform apply -var-file=nonprod.tfvars
```

---

### 4. Access EKS Cluster

```bash
# Configure kubectl
aws eks update-kubeconfig \
  --name nonprod-eks \
  --region us-east-1

# Verify
kubectl get nodes
kubectl get pods -A
```

---

## 📝 Configuration


## nonprod.tfvars (Development)

## prod.tfvars (Production)


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
# List resources
terraform state list

# Refresh state
terraform refresh -var-file=nonprod.tfvars

# Force unlock (if crashed)
terraform force-unlock <LOCK_ID>
```

---

## 🐛 Troubleshooting

### Expired Credentials
```bash
rm -rf ~/.aws/cli/cache/*
export AWS_PROFILE=devops-role
aws sts get-caller-identity
```

### Subnet Conflicts
```bash
# Destroy and recreate
terraform destroy -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

### Provider Issues
```bash
rm -rf .terraform/
terraform init
```

---

## 🗑️ Cleanup

```bash
# Preview deletion
terraform plan -destroy -var-file=nonprod.tfvars

# Destroy
terraform destroy -var-file=nonprod.tfvars
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

**Stage 2: Kubernetes Foundation**
- Install NGINX Ingress Controller
- Deploy cert-manager for TLS
- Setup metrics-server

**Stage 3: Platform Services**
- Deploy Nexus repository
- Setup SonarQube
- Configure persistent storage

---

**Last Updated:** January 29, 2026  
**Terraform:** >= 1.6.0 | **Kubernetes:** 1.35