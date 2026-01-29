# Cloud-Native DevOps Platform

> **Status:** 🚧 Stage 1 - Infrastructure Provisioning with Terraform

A cloud-native DevOps platform showcasing modern infrastructure and CI/CD practices.

**Presented by:** Omar Higgy

---

## 📖 Overview

Building a complete DevOps platform on AWS using Infrastructure as Code, Kubernetes, and GitOps workflows. This project demonstrates cloud-native best practices from infrastructure setup to automated deployments.

---

## 🎯 Current Progress

### Stage 1: Infrastructure Provisioning ⏳
Setting up AWS foundation with Terraform:
- AWS VPC with multi-tier subnets
- EKS cluster deployment
- Environment isolation (nonprod/prod)

**Tools:** Terraform, AWS VPC, AWS EKS

---

## 🗺️ Planned Stages

1. ✅ **Infrastructure** - Terraform & AWS EKS
2. ⏳ **Networking** - Ingress, API Gateway & Security
3. ⏳ **Platform Services** - Nexus, SonarQube, Argo CD
4. ⏳ **Microservices** - Docker & Helm
5. ⏳ **CI Pipeline** - Azure DevOps & Security Scanning
6. ⏳ **CD Pipeline** - GitOps with Argo CD
7. ⏳ **Secrets** - HashiCorp Vault
8. ⏳ **Monitoring** - MongoDB Atlas & Datadog

---

## 🛠️ Tech Stack

**Current:** Terraform, AWS VPC, AWS EKS

**Planned:** Kubernetes, Helm, Azure DevOps, Argo CD, Docker, HashiCorp Vault, Nexus, SonarQube, Datadog

---

## 🚀 Getting Started

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

## 📝 Updates

- **Jan 29, 2026** - Project initialized, starting infrastructure provisioning

---

_This README will be updated as the project progresses through each stage._