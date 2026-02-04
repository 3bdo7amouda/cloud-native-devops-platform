# 🏗️ Cloud-Native DevOps Platform

**NTI Graduation Project** | Production-ready EKS platform with full CI/CD automation

---

## 📖 What is This?

A complete end-to-end DevOps platform demonstrating:
- Infrastructure as Code with Terraform
- Kubernetes on AWS EKS
- Automated CI/CD pipelines
- GitOps deployment patterns
- Enterprise-grade security & observability

---

## 🎯 Project Status

| Phase | Component | Status |
|-------|-----------|--------|
| 1️⃣ | Infrastructure (Terraform) | ✅ Complete |
| 2️⃣ | CI/CD Pipeline (Azure DevOps) | ✅ Complete |
| 3️⃣ | Platform Services (Helm) | 🚧 Next |
| 4️⃣ | Application Deployment | 📋 Planned |
| 5️⃣ | GitOps with Argo CD | 📋 Planned |

**Legend:** ✅ Done | 🚧 In Progress | 📋 Planned

---

## 📂 Repository Structure

```
📁 terraform/           Infrastructure as Code (AWS EKS, VPC, IAM)
📁 voting-app/          Sample microservices app (Python, Node.js, .NET)
📁 helm-charts/         Kubernetes deployment manifests
📁 k8s-config/          Platform services (ingress, cert-manager, etc.)
📁 vault-config/        Secrets management setup
📄 azure-pipelines-infra.yml    Automated infrastructure pipeline
```

---

## 🛠️ Technology Stack

### Infrastructure
- **Terraform** - Infrastructure as Code
- **AWS EKS** - Kubernetes cluster
- **VPC, NAT, Subnets** - Network setup
- **API Gateway + Cognito** - API layer & auth

### Application
- **Python/Flask** - Vote frontend
- **Node.js** - Results display
- **.NET** - Background worker
- **Redis** - Message queue
- **MongoDB** - Database

### DevOps Tools
- **Azure DevOps** - CI/CD pipelines
- **Helm** - Kubernetes package manager
- **Argo CD** - GitOps (planned)
- **Vault** - Secrets (planned)
- **Datadog** - Monitoring (planned)

---

## 🚀 Quick Start

### Prerequisites
Tools needed (pre-installed on our CI/CD agent):
- AWS CLI
- kubectl
- Helm
- Terraform

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform apply -var-file=nonprod.tfvars
```

**Or use the Azure Pipeline** for automated deployment.

### Step 2: Access the Cluster
```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
kubectl get nodes
```

### Step 3: Deploy Applications
See detailed guides in each directory:
- [terraform/README.md](terraform/README.md) - Infrastructure setup
- [voting-app/README.md](voting-app/README.md) - Application build
- [helm-charts/README.md](helm-charts/README.md) - Deployment guide
- [k8s-config/README.md](k8s-config/README.md) - Platform services

---

## 📊 Architecture

```
Internet → API Gateway (JWT Auth) → VPC Link → NLB 
    → ingress-nginx → Kubernetes Services → Pods
```

**Components:**
- **VPC** with public/private subnets
- **EKS Cluster** (v1.32) with managed node groups
- **API Gateway** for external access with Cognito authentication
- **NAT Gateway** for outbound internet from private subnets
- **IRSA** for secure AWS permissions to pods

---

## 🎓 Learning Outcomes

This project demonstrates:
- ✅ Multi-module Terraform architecture
- ✅ AWS networking best practices
- ✅ Kubernetes security with IRSA
- ✅ CI/CD automation
- ✅ GitOps workflows
- ✅ Secrets management
- ✅ Container orchestration

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [terraform/](terraform/) | Infrastructure deployment guide |
| [voting-app/](voting-app/) | Application source code & build |
| [helm-charts/](helm-charts/) | Kubernetes deployment |
| [k8s-config/](k8s-config/) | Platform services setup |
| [vault-config/](vault-config/) | Secrets management |

---

## 🗑️ Cleanup

**Using Pipeline:**
Run pipeline with `destroy: true`

**Using CLI:**
```bash
cd terraform
terraform destroy -var-file=nonprod.tfvars
```

---

## 👨‍💻 Author

**Abdelrahman Hamouda**  
NTI Graduation Project - February 2026

---

_Clean, simple, production-ready DevOps platform_ ✨
