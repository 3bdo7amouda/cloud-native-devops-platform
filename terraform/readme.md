# Infrastructure Provisioning - Terraform

> **Stage 1** of Cloud-Native DevOps Platform

This directory contains Terraform configuration for provisioning the AWS infrastructure foundation.

---

## 📋 What Gets Provisioned

### VPC Module
- **VPC** with DNS support and hostnames enabled
- **Internet Gateway** for public internet access
- **Public Subnets** (2) across multiple AZs with auto-assign public IP
- **Private Subnets** (2) across multiple AZs for internal resources
- **NAT Gateway** with Elastic IP for private subnet internet access
- **Route Tables** for public and private subnets

### Planned (Not Yet Implemented)
- EKS Cluster with Fargate & Managed Node Groups
- IAM Roles and Policies
- Security Groups
- Additional networking components

---

## 📁 Structure

```
terraform/
├── main.tf                 # Root module - calls VPC module
├── variables.tf            # Root variables
├── outputs.tf              # Root outputs
├── providers.tf            # AWS provider configuration
├── backend.tf              # S3 backend with state locking
├── nonprod.tfvars          # Non-production environment values
├── prod.tfvars             # Production environment values (future)
└── modules/
    └── vpc/
        ├── main.tf         # VPC resources
        ├── variables.tf    # VPC module variables
        └── outputs.tf      # VPC module outputs
```

---

## 🔧 Prerequisites

- **Terraform** >= 1.6.0
- **AWS CLI** configured with credentials
- **AWS Account** with appropriate permissions
- **S3 Bucket** for state storage: `cloud-native-devops-platform-terraform-bucket`

---

## ⚙️ AWS Configuration

### Profile Setup

Credentials are configured to use an assumed role:

**`~/.aws/credentials`**
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

**`~/.aws/config`**
```ini
[default]
region = us-east-1

[profile devops-role]
role_arn = arn:aws:iam::430118836758:role/terraform-deploy-role
source_profile = default
region = us-east-1
```

### Set Profile
```bash
export AWS_PROFILE=devops-role
```

---

## 🚀 Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
# For nonprod environment
terraform plan -var-file=nonprod.tfvars

# For prod environment (when ready)
terraform plan -var-file=prod.tfvars
```

### Apply Infrastructure
```bash
# Nonprod
terraform apply -var-file=nonprod.tfvars

# With auto-approve
terraform apply -var-file=nonprod.tfvars --auto-approve
```

### Destroy Infrastructure
```bash
terraform destroy -var-file=nonprod.tfvars
```

---

## 📝 Configuration Files

### nonprod.tfvars
Contains environment-specific values for non-production:
- VPC CIDR blocks
- Subnet configurations
- Availability zones
- Resource tags

### backend.tf
S3 backend configuration:
- **Bucket**: `cloud-native-devops-platform-terraform-bucket`
- **Region**: `us-east-1`
- **Encryption**: Enabled
- **State Locking**: S3 native locking (`use_lockfile = true`)

---

## 🔒 State Management

### Remote State (S3)
- State file stored in S3 for team collaboration
- Encryption at rest enabled
- Native S3 state locking (no DynamoDB needed)

### State Lock
If you encounter a state lock issue:
```bash
terraform force-unlock <LOCK_ID>
```

---

## 📊 Outputs

After applying, you can view outputs:

```bash
terraform output

# Specific output
terraform output vpc_id
terraform output public_subnet_ids
```

---

## 🏷️ Tagging Strategy

All resources are tagged with:
- `Environment` - nonprod/prod
- `Project` - cloud-native-devops
- `ManagedBy` - terraform
- `Name` - Resource-specific identifier

---

## 🐛 Troubleshooting

### Expired AWS Credentials
```bash
# Check credentials
aws sts get-caller-identity

# If expired, refresh credentials in ~/.aws/credentials
```

### State Lock Issues
```bash
# Force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

### Provider Version Issues
```bash
# Re-initialize
rm -rf .terraform
terraform init
```

---

## 📖 Variables Reference

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `name_prefix` | string | Prefix for resource names | `devops-nonprod` |
| `vpc_cidr` | string | VPC CIDR block | `10.0.0.0/16` |
| `azs` | list(string) | Availability zones | `["us-east-1a", "us-east-1b"]` |
| `public_subnet_cidrs` | list(string) | Public subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `private_subnet_cidrs` | list(string) | Private subnet CIDRs | `["10.0.11.0/24", "10.0.12.0/24"]` |
| `tags` | map(string) | Common resource tags | `{ Environment = "nonprod" }` |

---

## ✅ Current Status

- [x] Terraform configuration structure
- [x] VPC module with networking components
- [x] S3 backend with state locking
- [x] Environment separation (nonprod/prod)
- [ ] EKS cluster module
- [ ] IAM roles and policies
- [ ] Security groups

---

## 🔜 Next Steps

1. Add EKS cluster module
2. Configure IAM roles for EKS
3. Set up security groups
4. Implement prod environment
5. Add terraform.tfvars.example for documentation

---

**Last Updated:** January 29, 2026