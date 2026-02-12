# 🧱 Terraform Infrastructure

Terraform configuration for the platform AWS foundation: VPC networking extensions, IAM roles, EKS cluster, IRSA roles, API Gateway routing, Cognito, and load balancer integration.

## 🗂️ Layout

| Path | Description |
| --- | --- |
| `backend.tf` | Remote backend configuration (S3 state) |
| `providers.tf` | Terraform and AWS provider constraints |
| `main.tf` | Root module wiring |
| `variables.tf` | Root module inputs |
| `outputs.tf` | Root module outputs |
| `nonprod.tfvars` | Non-production environment values |
| `modules/` | Reusable module implementations |

## 🧭 Root Module Flow

1. `modules/networking` prepares networking and edge resources.
2. `modules/iam` creates IAM roles for EKS and Fargate.
3. `modules/eks` creates cluster, node group, Fargate profile, add-ons.
4. `modules/irsa` creates OIDC provider and IRSA roles.

## 🧩 Module Details

### 🌐 `modules/networking`

Creates:
- Public and private subnets
- Route tables and associations
- NAT gateway and EIP
- API Gateway HTTP API with optional Cognito JWT authorizer
- Optional API custom domain with Route53 validation/alias
- Internal NLB and target group for API Gateway VPC Link backend
- Optional internal ALB for Nexus registry with ACM + Route53

Key inputs:
- `vpc_id`, `azs`, `public_subnet_cidrs`, `private_subnet_cidrs`
- `existing_public_subnet_id`, `existing_igw_id`, `existing_public_route_table_id`
- `enable_api_gateway`, `api_name`, `api_integration_uri`
- `enable_cognito`, `cognito_user_pool_name`
- `api_custom_domain`, `hosted_zone_id`
- `nexus_registry_domain`, `nexus_registry_target_ip`, `nexus_registry_target_port`

Key outputs:
- `public_subnet_ids`, `private_subnet_ids`
- `api_gateway_endpoint`, `api_custom_domain`
- `nlb_dns_name`, `nlb_target_group_arn`
- `nexus_registry_alb_dns_name`, `nexus_registry_certificate_arn`
- `cognito_user_pool_id`, `cognito_app_client_id`

### 🔐 `modules/iam`

Creates:
- EKS cluster role (`AmazonEKSClusterPolicy`)
- EKS node role (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`)
- Fargate pod execution role (`AmazonEKSFargatePodExecutionRolePolicy`)

Outputs:
- `cluster_role_arn`
- `node_role_arn`
- `fargate_pod_execution_role_arn`

### ☸️ `modules/eks`

Creates:
- EKS cluster with access mode `API_AND_CONFIG_MAP`
- Cluster access entries/policy associations (from `cluster_access_entries`)
- Managed node group for platform workloads
- Fargate profile targeting namespace `voting-app`
- Managed add-ons: `vpc-cni`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver`

Key outputs:
- `cluster_name`, `cluster_endpoint`, `cluster_security_group_id`
- `oidc_issuer_url`
- `node_group_id`, `node_group_status`
- `fargate_profile_id`

### 🪪 `modules/irsa`

Creates:
- IAM OIDC provider for EKS issuer URL
- One IAM role per item in `irsa_roles`
- Policy attachments for each role

Input object shape:

```hcl
irsa_roles = {
  aws_load_balancer_controller = {
    namespace            = "kube-system"
    service_account_name = "aws-load-balancer-controller"
    policy_arns          = ["arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy"]
  }
}
```

Outputs:
- `oidc_provider_arn`
- `irsa_role_arns`

## ✅ Prerequisites

- Terraform `>= 1.6.0`
- AWS credentials with required permissions
- Existing VPC and (optionally) existing public subnet/IGW IDs if reusing network assets
- Existing backend S3 bucket configured in `backend.tf`

## 🚀 Deploy

```bash
cd terraform
terraform init
terraform plan -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

## 🧹 Destroy

```bash
cd terraform
terraform destroy -var-file=nonprod.tfvars
```

## 🧾 Important Root Inputs

- `cluster_name`, `cluster_version`
- `vpc_id`, `azs`, subnet CIDRs
- `existing_public_subnet_id`, `existing_igw_id`
- `enable_api_gateway`, `enable_cognito`
- `api_custom_domain`, `hosted_zone_id`
- `nexus_registry_domain`, `nexus_registry_target_ip`, `nexus_registry_target_port`
- `cluster_access_entries`

## 📤 Key Root Outputs

- EKS: `cluster_name`, `cluster_endpoint`, `oidc_issuer_url`
- Identity: `irsa_role_arns`, Cognito IDs
- API edge: `api_gateway_endpoint`, `api_custom_domain`
- Network entrypoint: `nlb_dns_name`, `nlb_target_group_arn`
- Compute: `node_group_status`, `fargate_profile_id`

## 📝 Notes

- `nonprod.tfvars` currently sets `cluster_version = "1.35"`.
- `voting-app` namespace is selected by a dedicated Fargate profile.
- Internal ALB resources are connected to Terraform-managed NLB target group by `azure-pipelines-helm.yml`.
