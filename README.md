# Cloud-Native DevOps Platform

> **A production-ready DevOps platform on AWS**

**Presented by:** Abdelrahman Hamouda

---

## 📖 Overview

End-to-end cloud-native platform demonstrating Infrastructure as Code, Kubernetes orchestration, CI/CD automation, and GitOps workflows on AWS. This repository is the single source of truth: **infrastructure** (Terraform), **application** (Voting App), and **deployment** (Helm) are organized in a linked structure.

---

## 📂 Repository Structure (linked)

| Path | Purpose | Documentation |
|------|---------|---------------|
| **[terraform/](terraform/README.md)** | AWS infrastructure: VPC, EKS, IAM. Provision the cluster first. | [Terraform README](terraform/README.md) |
| **[voting-app/](voting-app/README.md)** | Microservices source code: **vote**, **result**, **worker**. Build context for container images. | [Voting App README](voting-app/README.md) |
| **[helm/](helm/README.md)** | Kubernetes Helm chart for the Voting App. Deploys vote, result, worker, and Redis. | [Helm README](helm/README.md) |

**Flow:** Provision cluster with **Terraform** → Build images from **voting-app/** → Deploy with **Helm** (chart in **helm/**).

```
cloud-native-devops-platform/
├── README.md                 # This file — guide and links
├── terraform/                # Stage 1: Infrastructure
│   ├── README.md             # Terraform guide
│   ├── main.tf, variables.tf, outputs.tf, backend.tf, providers.tf
│   ├── prod.tfvars / (nonprod via variables)
│   └── modules/              # vpc, iam, eks
├── voting-app/               # Application source
│   ├── README.md             # Voting App guide
│   ├── vote/                 # Python/Flask — build context for vote image
│   ├── result/               # Node.js — build context for result image
│   └── worker/               # .NET — build context for worker image
└── helm/                     # Deployment chart
    ├── README.md             # Helm guide
    ├── Chart.yaml
    ├── values.yaml, values-minikube.yaml, values-nonprod.yaml, values-prod.yaml
    └── templates/            # vote, result, worker, redis, ingress
```

---

## 🎯 Status

### ✅ Stage 1: Infrastructure (COMPLETE)
- Multi-tier VPC with public/private subnets
- EKS cluster (Kubernetes 1.35) with managed nodes
- IAM roles and essential addons
- Multi-environment (nonprod/prod)

### ✅ Application & Deployment
- Voting App: vote, result, worker microservices in **voting-app/**
- Helm chart in **helm/** for local (Minikube) and deployed (EKS) use

📚 **[Infrastructure →](terraform/README.md)**  
📦 **[Voting App source →](voting-app/README.md)**  
🚀 **[Helm deployment →](helm/README.md)**

---

## 🗺️ Roadmap

| Stage | Status | Focus |
|-------|--------|-------|
| **1. Infrastructure** | ✅ | Terraform, AWS EKS, VPC |
| **2. Networking** | ⏳ | NGINX Ingress, cert-manager |
| **3. Platform Services** | ⏳ | Nexus, SonarQube, Argo CD |
| **4. Microservices** | ✅ | Voting App, Helm chart |
| **5. CI Pipeline** | ⏳ | Azure DevOps (configure in console) |
| **6. CD Pipeline** | ⏳ | GitOps with Argo CD |
| **7. Secrets** | ⏳ | HashiCorp Vault |
| **8. Observability** | ⏳ | Datadog, MongoDB Atlas |

---

## 🛠️ Tech Stack

**Infrastructure:** Terraform, AWS (VPC, EKS, IAM, S3)  
**Orchestration:** Kubernetes 1.35, Helm  
**Application:** Python/Flask (vote), Node.js (result), .NET (worker), Redis, MongoDB Atlas  
**CI/CD:** Azure DevOps (pipelines configured manually), Argo CD (planned)  
**DevOps Tools:** Nexus, SonarQube, Vault (planned)  
**Monitoring:** Datadog, CloudWatch (planned)

---

## 🚀 Quick Start (high level)

1. **Provision cluster**  
   See [terraform/README.md](terraform/README.md): `terraform init` → `plan` → `apply` with your tfvars.

2. **Configure kubectl**  
   `aws eks update-kubeconfig --name <cluster-name> --region <region>`

3. **Build and push images**  
   Build from **voting-app/vote**, **voting-app/result**, **voting-app/worker** (e.g. in Azure DevOps or locally), push to your registry (ACR/ECR).

4. **Deploy the app**  
   From repo root, using [helm/README.md](helm/README.md): set image registry in values, then  
   `helm upgrade --install voting-app ./helm --values ./helm/values-nonprod.yaml`

5. **Create MongoDB secret**  
   Create the `mongodb-atlas-credentials` secret in the cluster as described in [helm/README.md](helm/README.md).

---

## 📊 Architecture

**Current (Stage 1 + Voting App):**
```
AWS Cloud
└── VPC (Multi-AZ)
    ├── Public Subnets (IGW, NAT)
    ├── Private Subnets (EKS Nodes)
    └── EKS Cluster
        ├── Managed Node Groups
        ├── Addons (CNI, DNS, Storage)
        └── Voting App (Helm)
            ├── vote (LoadBalancer)
            ├── result (LoadBalancer)
            ├── worker
            └── redis (ClusterIP)
```

---

## 📚 Documentation Index

- **[README.md](README.md)** (this file) — Guide and linked structure
- **[terraform/README.md](terraform/README.md)** — Infrastructure provisioning
- **[voting-app/README.md](voting-app/README.md)** — Application source and build context
- **[helm/README.md](helm/README.md)** — Helm chart: local (Minikube) vs deployed (EKS)

---

## 📝 Changelog

**January 29, 2026**
- ✅ Stage 1 complete: Infrastructure foundation
- Terraform modules for VPC, IAM, EKS; multi-environment; remote state (S3)
- Voting App and Helm chart; linked README structure

---

_Last Updated: January 29, 2026 | Main README as guide_
