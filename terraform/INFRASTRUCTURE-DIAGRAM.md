# 🏗️ Cloud-Native DevOps Platform - Infrastructure Flow

## 📊 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          INTERNET (Public Access)                            │
└────────────┬─────────────────────────────────────────────────┬───────────────┘
             │                                                  │
             │                                                  │
   ┌─────────▼──────────┐                           ┌──────────▼──────────┐
   │   API Gateway      │                           │  Application UIs    │
   │    (HTTPS)         │                           │   (via Ingress)     │
   │                    │                           │                     │
   │  - /api/*          │                           │ vote.domain.com     │
   │  - /auth/*         │                           │ result.domain.com   │
   │                    │                           │ argocd.domain.com   │
   │  JWT Authorizer    │                           │ vault.domain.com    │
   │  (Cognito)         │                           │                     │
   └─────────┬──────────┘                           └──────────┬──────────┘
             │                                                  │
             │                                                  │
        ┌────▼────────────────────────────────────────────────▼────┐
        │              VPC Link / Network Load Balancer            │
        │                  (Created by ingress-nginx)              │
        └────┬─────────────────────────────────────────────────────┘
             │
             │
    ┌────────▼────────────────────────────────────────────────────┐
    │                     VPC (172.30.0.0/16)                     │
    │                                                              │
    │  ┌──────────────────────────┬──────────────────────────┐   │
    │  │   Public Subnets         │   Private Subnets        │   │
    │  │   172.30.1.0/24 (AZ-a)   │   172.30.11.0/24 (AZ-a)  │   │
    │  │   172.30.2.0/24 (AZ-b)   │   172.30.12.0/24 (AZ-b)  │   │
    │  │                          │                          │   │
    │  │  ┌──────────────┐        │  ┌─────────────────┐    │   │
    │  │  │ NAT Gateway  │        │  │   EKS Cluster   │    │   │
    │  │  │ Internet GW  │        │  │                 │    │   │
    │  │  └──────────────┘        │  │  ┌───────────┐  │    │   │
    │  │                          │  │  │ Node Group│  │    │   │
    │  └──────────────────────────┤  │  │ t3.medium │  │    │   │
    │                             │  │  │ Min: 1    │  │    │   │
    │                             │  │  │ Max: 2    │  │    │   │
    │                             │  │  └───────────┘  │    │   │
    │                             │  └─────────────────┘    │   │
    │                             └──────────────────────────┘   │
    └──────────────────────────────────────────────────────────┘
```

---

## 🔐 Security & Identity Flow

```
┌──────────────────────────────────────────────────────────────┐
│                     AWS IAM & IRSA                            │
│                                                               │
│  ┌─────────────────┐      ┌────────────────────────┐        │
│  │  EKS Cluster    │      │  OIDC Provider         │        │
│  │  IAM Role       │      │  (For IRSA)            │        │
│  └─────────────────┘      └────────────┬───────────┘        │
│                                        │                     │
│  ┌─────────────────┐                   │                     │
│  │  Node Group     │      ┌────────────▼───────────┐        │
│  │  IAM Role       │      │  IRSA Roles:           │        │
│  │  - EKS Worker   │      │  - EBS CSI Driver      │        │
│  │  - CNI Policy   │      │  - cert-manager        │        │
│  │  - ECR Read     │      │  - External Secrets    │        │
│  │  - SSM Core     │      │  - Datadog             │        │
│  └─────────────────┘      └────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│              Cognito Authentication                           │
│                                                               │
│  ┌────────────┐       ┌──────────────┐                       │
│  │ User Pool  │──────▶│ App Client   │                       │
│  │            │       │ (No Secret)  │                       │
│  └────────────┘       └──────┬───────┘                       │
│                              │                                │
│                              ▼                                │
│                       ┌──────────────┐                        │
│                       │  JWT Tokens  │                        │
│                       └──────────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

---

## 🎯 Traffic Flow Patterns

### Pattern 1: API Traffic (Backend Services)
```
Client Request
    │
    ├─▶ HTTPS Request to API Gateway
    │       │
    │       ├─▶ JWT Authorizer validates Cognito token
    │       │
    │       ├─▶ VPC Link (Private connection)
    │       │
    │       ├─▶ Network Load Balancer
    │       │
    │       ├─▶ ingress-nginx Controller
    │       │
    │       └─▶ Backend Service (in EKS)
    │
    └─▶ Response with data
```

### Pattern 2: UI Traffic (Frontend Applications)
```
Client Request
    │
    ├─▶ HTTPS Request to vote.domain.com
    │       │
    │       ├─▶ Route53 DNS resolution
    │       │
    │       ├─▶ Network Load Balancer
    │       │
    │       ├─▶ ingress-nginx Controller
    │       │
    │       ├─▶ Ingress Rule routes to service
    │       │
    │       └─▶ Vote Pod (in EKS)
    │
    └─▶ Response with HTML/UI
```

---

## 🔧 EKS Cluster Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      EKS Cluster (v1.32)                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Core Addons (AWS Managed)                     │ │
│  │  • vpc-cni      → Pod networking                          │ │
│  │  • coredns      → DNS resolution                          │ │
│  │  • kube-proxy   → Service networking                      │ │
│  │  • ebs-csi      → Persistent volumes                      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Platform Services (Helm Charts)                  │ │
│  │                                                            │ │
│  │  ┌─────────────────────┐  ┌────────────────────────┐     │ │
│  │  │ AWS LB Controller   │  │  ingress-nginx         │     │ │
│  │  │ (Creates NLB)       │  │  (Entry point)         │     │ │
│  │  └─────────────────────┘  └────────────────────────┘     │ │
│  │                                                            │ │
│  │  ┌─────────────────────┐  ┌────────────────────────┐     │ │
│  │  │ cert-manager        │  │  Argo CD               │     │ │
│  │  │ (TLS/Let's Encrypt) │  │  (GitOps)              │     │ │
│  │  └─────────────────────┘  └────────────────────────┘     │ │
│  │                                                            │ │
│  │  ┌─────────────────────┐  ┌────────────────────────┐     │ │
│  │  │ Vault               │  │  External Secrets (ESO)│     │ │
│  │  │ (Secret storage)    │  │  (Secret sync)         │     │ │
│  │  └─────────────────────┘  └────────────────────────┘     │ │
│  │                                                            │ │
│  │  ┌─────────────────────┐                                  │ │
│  │  │ Datadog Agent       │                                  │ │
│  │  │ (Observability)     │                                  │ │
│  │  └─────────────────────┘                                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Application Workloads                         │ │
│  │                                                            │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │ │
│  │  │  Vote    │  │  Redis   │  │  Worker  │  │  Result  │ │ │
│  │  │   Pod    │  │   Pod    │  │   Pod    │  │   Pod    │ │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Secrets Management Flow

```
┌────────────────────────────────────────────────────────────────┐
│                    Secrets Lifecycle                            │
│                                                                 │
│  1. Store Secret                                                │
│     ┌──────────┐                                                │
│     │  Vault   │ ◀── Admin stores secrets                       │
│     └────┬─────┘                                                │
│          │                                                       │
│  2. Sync to Kubernetes                                          │
│          │                                                       │
│     ┌────▼──────────┐                                           │
│     │ External      │ ─── Reads from Vault via IRSA             │
│     │ Secrets (ESO) │                                           │
│     └────┬──────────┘                                           │
│          │                                                       │
│  3. Create K8s Secret                                           │
│          │                                                       │
│     ┌────▼──────────┐                                           │
│     │ Kubernetes    │ ─── Native K8s secret                     │
│     │ Secret        │                                           │
│     └────┬──────────┘                                           │
│          │                                                       │
│  4. Mount to Pod                                                │
│          │                                                       │
│     ┌────▼──────────┐                                           │
│     │ Application   │ ─── Reads as environment variable         │
│     │ Pod           │                                           │
│     └───────────────┘                                           │
│                                                                 │
│  Examples:                                                      │
│  • mongodb/uri       → Vote/Result/Worker apps                 │
│  • nexus/password    → CI pipeline                             │
│  • datadog/api_key   → Datadog agent                           │
└────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Deployment Pipeline Flow

```
┌────────────────────────────────────────────────────────────────┐
│              CI/CD Pipeline Architecture                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Pipeline 1: Infrastructure (Terraform)                 │   │
│  │  ─────────────────────────────────────────────────      │   │
│  │  Git Push → Azure DevOps → Terraform Apply → AWS       │   │
│  │                                                         │   │
│  │  Creates:                                               │   │
│  │  ✓ VPC, Subnets, NAT, IGW                              │   │
│  │  ✓ EKS Cluster + Node Group                            │   │
│  │  ✓ IAM Roles + IRSA                                    │   │
│  │  ✓ API Gateway + Cognito                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Pipeline 2: Platform (Helm Charts)                     │   │
│  │  ───────────────────────────────────────────────────    │   │
│  │  Git Push → Azure DevOps → Helm Install → EKS          │   │
│  │                                                         │   │
│  │  Installs:                                              │   │
│  │  ✓ AWS LB Controller                                   │   │
│  │  ✓ ingress-nginx (creates NLB)                         │   │
│  │  ✓ cert-manager                                        │   │
│  │  ✓ Argo CD                                             │   │
│  │  ✓ Vault + External Secrets                            │   │
│  │  ✓ Datadog                                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Pipeline 3: Application CI (Voting App)                │   │
│  │  ────────────────────────────────────────────────────   │   │
│  │  Git Push → SonarQube → Build → Trivy → Nexus          │   │
│  │                                                         │   │
│  │  Steps:                                                 │   │
│  │  1. Code quality scan (SonarQube)                      │   │
│  │  2. Build Docker images                                │   │
│  │  3. Security scan (Trivy + Gitleaks)                   │   │
│  │  4. Push to Nexus registry                             │   │
│  │  5. Update Helm values in Git                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  GitOps: Argo CD Auto-Deploy                           │   │
│  │  ───────────────────────────────────────────────────    │   │
│  │  Argo CD watches Git → Detects change → Deploys to EKS │   │
│  │                                                         │   │
│  │  Deploys:                                               │   │
│  │  ✓ Vote app                                            │   │
│  │  ✓ Result app                                          │   │
│  │  ✓ Worker app                                          │   │
│  │  ✓ Redis                                               │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

---

## 🌐 DNS & Domain Structure

```
┌────────────────────────────────────────────────────────────────┐
│                Route 53 Hosted Zone                             │
│                   (3bdo7amouda.tech)                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Subdomain          Target              Purpose          │  │
│  │  ────────────       ──────────────      ────────────     │  │
│  │  vote.              NLB DNS             Voting UI        │  │
│  │  result.            NLB DNS             Result UI        │  │
│  │  argocd.            NLB DNS             Argo CD UI       │  │
│  │  vault.             NLB DNS             Vault UI         │  │
│  │  nexus.             VM IP               Nexus UI         │  │
│  │  sonarqube.         NLB DNS (optional)  SonarQube UI     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  All subdomains get TLS certificates from Let's Encrypt        │
│  via cert-manager using DNS-01 challenge                       │
└────────────────────────────────────────────────────────────────┘
```

---

## 📦 Data Persistence

```
┌────────────────────────────────────────────────────────────────┐
│                  Storage Architecture                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  EBS CSI Driver (AWS Managed)                           │   │
│  │  ────────────────────────────────────                   │   │
│  │  Provides persistent volumes for:                       │   │
│  │  • Vault data                                           │   │
│  │  • Argo CD data                                         │   │
│  │  • Any stateful workloads                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  MongoDB Atlas (External - Managed Service)             │   │
│  │  ────────────────────────────────────────────────        │   │
│  │  Database for Voting App:                               │   │
│  │  • Vote data storage                                    │   │
│  │  • Result aggregation                                   │   │
│  │  • Worker processing queue                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  S3 Bucket (Terraform State)                            │   │
│  │  ────────────────────────────                            │   │
│  │  • terraform.tfstate                                    │   │
│  │  • State locking (DynamoDB)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

---

## 🎬 Deployment Order (Critical!)

```
┌────────────────────────────────────────────────────────────────┐
│         STAGE 1: One-Time Prerequisites                         │
│         ────────────────────────────────                        │
│         ✓ Buy domain (3bdo7amouda.tech)                        │
│         ✓ Create Route53 hosted zone                           │
│         ✓ Create S3 bucket for Terraform state                 │
│         ✓ Setup Azure DevOps (org, project, pipelines)         │
│         ✓ Create MongoDB Atlas cluster                         │
│         ✓ Setup Nexus on EC2/VM                                │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│         STAGE 2: Infrastructure (Pipeline 1)                    │
│         ────────────────────────────────────                    │
│         Run: terraform apply -var-file=nonprod.tfvars          │
│         Creates: VPC, EKS, IAM, API Gateway, Cognito           │
│         Duration: ~15 minutes                                  │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│         STAGE 3: Platform Services (Pipeline 2)                 │
│         ────────────────────────────────────────                │
│         Install order (CRITICAL):                               │
│         1. AWS Load Balancer Controller                        │
│         2. ingress-nginx (wait for NLB creation)               │
│         3. cert-manager                                        │
│         4. Argo CD                                             │
│         5. Vault                                               │
│         6. External Secrets Operator                            │
│         7. Datadog agent                                       │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│         STAGE 4: DNS Configuration                              │
│         ──────────────────────                                  │
│         Create Route53 A records pointing to NLB               │
│         • vote.3bdo7amouda.tech                                │
│         • result.3bdo7amouda.tech                              │
│         • argocd.3bdo7amouda.tech                              │
│         • vault.3bdo7amouda.tech                               │
└────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────┐
│         STAGE 5: Application Deployment (GitOps)                │
│         ────────────────────────────────────────                │
│         Argo CD auto-deploys from Git:                         │
│         • Voting app Helm chart                                │
│         • Creates ingress rules                                │
│         • Mounts secrets from Vault                            │
└────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Key Design Decisions

### ✅ Why API Gateway + Ingress (Separation of Concerns)
```
API Gateway (HTTPS)          ingress-nginx (HTTPS)
     │                              │
     ├─ /api/*                      ├─ vote.domain.com
     ├─ /auth/*                     ├─ result.domain.com
     │                              ├─ argocd.domain.com
     └─ JWT Protection              └─ vault.domain.com

Benefit: Clean separation between backend APIs and frontend UIs
```

### ✅ Why VPC Link
```
API Gateway → VPC Link → NLB → ingress-nginx → Pods
              (Private)   (Internal)

Benefit: API Gateway connects privately to EKS without exposing internals
```

### ✅ Why IRSA (IAM Roles for Service Accounts)
```
Pod → ServiceAccount → IRSA Role → AWS API
                       (No credentials in pod)

Benefit: Secure, no hardcoded credentials, fine-grained permissions
```

### ✅ Why Vault + External Secrets Operator
```
Vault (Source) → ESO (Sync) → K8s Secret → Pod (Consume)

Benefit: Centralized secret management, rotation, audit trail
```

---

## 📊 Resource Summary

| Component                | Count | Purpose                           |
|--------------------------|-------|-----------------------------------|
| VPC                      | 1     | Network isolation                 |
| Public Subnets           | 2     | NAT Gateway, future ALB           |
| Private Subnets          | 2     | EKS nodes, pods                   |
| NAT Gateway              | 1     | Outbound internet for pods        |
| Internet Gateway         | 1     | Inbound/outbound for public       |
| EKS Cluster              | 1     | Container orchestration           |
| Node Group               | 1     | Worker nodes (t3.medium)          |
| API Gateway HTTP API     | 1     | Backend API entry point           |
| Cognito User Pool        | 1     | Authentication                    |
| VPC Link                 | 1     | Private API Gateway → EKS         |
| Security Groups          | 2+    | Network access control            |
| IAM Roles                | 5+    | EKS, nodes, IRSA                  |
| Route53 Hosted Zone      | 1     | DNS management                    |

---

## 🎓 Learning Points

1. **Infrastructure as Code**: All infrastructure defined in Terraform
2. **GitOps**: Argo CD manages app deployments from Git
3. **Zero-Trust Security**: JWT tokens, IRSA, no hardcoded secrets
4. **High Availability**: Multi-AZ deployment for resilience
5. **Scalability**: Auto-scaling nodes, horizontal pod autoscaling
6. **Observability**: Datadog for monitoring, CloudWatch for logs
7. **DevSecOps**: Security scanning in CI pipeline (Trivy, SonarQube)

