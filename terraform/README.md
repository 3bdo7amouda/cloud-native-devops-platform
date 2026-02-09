# 🏗️ Terraform Infrastructure

**AWS EKS Infrastructure as Code**

---

## 📖 Overview

This directory contains Terraform code to deploy a complete AWS infrastructure:
- **EKS Cluster** (Kubernetes v1.32)
- **VPC Networking** (public/private subnets, NAT Gateway)
- **IAM Roles** (cluster, nodes, IRSA)
- **API Gateway + Cognito** (authentication layer)
- **Add-ons** (vpc-cni, CoreDNS, kube-proxy, EBS CSI)

---

## 📂 Structure

```
terraform/
├── backend.tf              Remote state (S3 + DynamoDB)
├── providers.tf            AWS provider configuration
├── main.tf                 Module orchestration
├── variables.tf            Input variables
├── outputs.tf              Output values
├── nonprod.tfvars          Non-production environment
└── modules/
    ├── networking/         VPC, subnets, NAT, API Gateway, Cognito
    ├── iam/                EKS cluster & node IAM roles
    ├── eks/                EKS cluster, node groups, add-ons
    └── irsa/               OIDC provider, service account roles
```

---

## 🛠️ What Gets Created

### Networking
- **VPC** - Uses existing VPC
- **Subnets** - 1 public (for NAT), 2 private (for EKS)
- **NAT Gateway** - Outbound internet for private subnets
- **Route Tables** - Proper routing for all subnets
- **Internet Gateway** - Uses existing IGW

### Kubernetes (EKS)
- **EKS Cluster** - v1.32 control plane
- **Node Group** - Managed t3.medium instances (1-2 nodes)
- **Add-ons** - vpc-cni, CoreDNS, kube-proxy, EBS CSI driver

### Security & IAM
- **Cluster Role** - Permissions for EKS control plane
- **Node Role** - Permissions for worker nodes (EKS, CNI, ECR, SSM)
- **OIDC Provider** - For IRSA (IAM Roles for Service Accounts)
- **IRSA Roles** - EBS CSI driver role

### API Layer
- **API Gateway** - HTTP API for external access
- **Cognito** - User pool and client for JWT authentication
- **VPC Link** - Private connection from API Gateway to EKS
- **Custom Domain (optional)** - ACM cert + Route53 alias for API Gateway

---

## 🚀 Usage

### Prerequisites
- AWS CLI configured
- Terraform v1.6+
- S3 bucket for state storage
- Route53 hosted zone (optional, required for custom domain automation)

### Deploy Infrastructure

**1. Initialize Terraform**
```bash
terraform init
```

**2. Review the Plan**
```bash
terraform plan -var-file=nonprod.tfvars
```

**3. Deploy**
```bash
terraform apply -var-file=nonprod.tfvars
```

**4. Save Outputs**
```bash
terraform output -json > outputs.json
```

### Destroy Infrastructure
```bash
terraform destroy -var-file=nonprod.tfvars
```

---

## ⚙️ Configuration

### Environment Files

**nonprod.tfvars** - Non-production settings
```hcl
region         = "us-east-1"
cluster_name   = "nonprod-eks"
cluster_version = "1.32"
node_desired   = 1
node_min       = 1
node_max       = 2
instance_types = ["t3.medium"]
```

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | - |
| `cluster_name` | EKS cluster name | - |
| `cluster_version` | Kubernetes version | - |
| `vpc_id` | Existing VPC ID | - |
| `existing_igw_id` | Existing Internet Gateway | - |
| `existing_public_subnet_id` | Existing subnet (Nexus/Agent) | - |
| `azs` | Availability zones | - |
| `public_subnet_cidrs` | New public subnet CIDRs | - |
| `private_subnet_cidrs` | Private subnet CIDRs for EKS | - |
| `hosted_zone_id` | Route53 hosted zone ID (required for custom domain) | `null` |
| `api_custom_domain` | Custom domain for API Gateway (e.g., api.example.com) | `null` |

---

## 📤 Outputs

After deployment, capture these values:

```bash
cluster_name              # EKS cluster name
cluster_endpoint          # Kubernetes API endpoint
oidc_issuer_url           # OIDC provider URL
api_gateway_endpoint      # API Gateway URL
cognito_user_pool_id      # Cognito pool ID
cognito_app_client_id     # Cognito client ID
```

**Use outputs to:**
- Configure kubectl
- Set up CI/CD pipelines
- Configure applications

---

## 🏗️ Module Details

### networking/
- Creates public/private subnets
- Configures NAT Gateway
- Manages route tables
- Sets up API Gateway + Cognito
- Creates VPC Link for API Gateway

### iam/
- Creates EKS cluster IAM role
- Creates node group IAM role
- Attaches AWS managed policies

### eks/
- Deploys EKS cluster
- Creates managed node group
- Installs core add-ons (vpc-cni, CoreDNS, kube-proxy)

### irsa/
- Creates OIDC provider
- Configures IRSA roles (e.g., EBS CSI driver)
- Sets up trust relationships

---

## 🔐 Security Features

- **IRSA** - No hardcoded AWS credentials in pods
- **Private Subnets** - EKS nodes in private subnets
- **NAT Gateway** - Controlled outbound internet access
- **Security Groups** - Minimal required permissions
- **Encrypted State** - S3 state encryption enabled

---

## 🐛 Troubleshooting

**State Lock Error**
```bash
terraform force-unlock <LOCK_ID>
```

**Plan Changes on Every Run**
- Check if `existing_igw_id` and `existing_public_subnet_id` are set correctly

**Nodes Can't Pull Images**
- Verify NAT Gateway is running
- Check route tables for private subnets

**kubectl Connection Issues**
```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
```

---

## 📝 Notes

### Existing vs Created Resources

**Uses Existing:**
- VPC
- Internet Gateway
- Public subnet (172.30.2.0/24) - contains Nexus/Azure agent

**Creates New:**
- Public subnet (for NAT Gateway)
- Private subnets (for EKS nodes)
- NAT Gateway
- Route tables
- EKS cluster & nodes
- IAM roles
- API Gateway & Cognito

### Best Practices Applied
- ✅ Remote state in S3 with DynamoDB locking
- ✅ Modular architecture
- ✅ Environment-specific tfvars files
- ✅ Outputs for downstream usage
- ✅ Resource tagging
- ✅ IRSA instead of hardcoded credentials
- ✅ Private subnets for workloads

---

## 🔄 CI/CD Integration

This infrastructure is deployed via **Azure DevOps Pipeline**:
- Automated `terraform init`
- Automated `terraform plan`
- Automated `terraform apply`
- Support for destroy operations
- Multi-environment support (nonprod/prod)

See: `azure-pipelines-infra.yml` in the root directory

---

## 📚 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

_Clean, modular, production-ready infrastructure_ ✨
