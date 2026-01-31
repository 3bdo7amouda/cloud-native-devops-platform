# Cloud-Native DevOps Platform

> **A production-ready DevOps platform on AWS**

**Presented by:** Abdelrahman Hamouda

---

## 📖 Overview

End-to-end cloud-native platform demonstrating Infrastructure as Code, Kubernetes orchestration, CI/CD automation, and GitOps workflows on AWS. This repository is the single source of truth: **infrastructure** (Terraform), **application** (Voting App), and **deployment** (Helm) are organized in a linked structure.

---

## 📂 Repository Structure

| Path | Purpose | Documentation |
|------|---------|---------------|
| **[terraform/](terraform/README.md)** | AWS infrastructure: VPC, EKS, IAM, API Gateway, Cognito. Provision the cluster first. | [Terraform README](terraform/README.md) |
| **[voting-app/](voting-app/README.md)** | Microservices source code: **vote**, **result**, **worker**. Build context for container images. | [Voting App README](voting-app/README.md) |
| **[helm-charts/](helm-charts/README.md)** | Kubernetes Helm chart for the Voting App. Deploys vote, result, worker, and Redis. | [Helm README](helm-charts/README.md) |

**Flow:** Provision cluster with **Terraform** → Build images from **voting-app/** → Deploy with **Helm** (chart in **helm-charts/**).

```
cloud-native-devops-platform/
├── README.md                 # This file — guide and links
├── terraform/                # Stage 1: Infrastructure
│   ├── README.md             # Terraform guide
│   ├── main.tf, variables.tf, outputs.tf, backend.tf, providers.tf
│   ├── prod.tfvars
│   └── modules/
│       ├── networking/       # VPC, subnets, API Gateway, Cognito
│       ├── iam/              # EKS cluster + node roles
│       ├── eks/              # EKS cluster, node group, addons
│       └── irsa/             # OIDC provider, IRSA (e.g. EBS CSI)
├── voting-app/               # Application source
│   ├── vote/, result/, worker/
│   └── README.md
└── helm-charts/              # Deployment chart
    ├── Chart.yaml
    ├── values.yaml, values-minikube.yaml, values-nonprod.yaml, values-prod.yaml
    └── templates/            # vote, result, worker, redis, ingress
```

---

## 🎯 Status

### ✅ Infrastructure (Terraform)
- **Networking:** VPC, public/private subnets, IGW, NAT Gateway, routes, EKS subnet tags
- **EKS:** Cluster, managed node group, OIDC provider, cluster + node IAM roles
- **API & Auth:** API Gateway HTTP API, default stage (`$default`), Cognito user pool + client, JWT authorizer
- **IRSA:** OIDC provider (for future IRSA), EBS CSI driver addon with IRSA

### ✅ Application & Deployment
- Voting App: vote, result, worker microservices in **voting-app/**
- Helm chart in **helm-charts/** for local (Minikube) and deployed (EKS) use
- Ingress: **ingress-nginx** (Service type LoadBalancer), HTTP only; TLS handled at API Gateway

### Traffic flow (final minimal setup)
```
Client
  → API Gateway default HTTPS endpoint (https://<api-id>.execute-api.<region>.amazonaws.com)
  → JWT validated by Cognito
  → NLB (HTTP)
  → ingress-nginx
  → Service (HTTP)
```
**One HTTPS termination point (API Gateway).** No ACM, no custom domain, no cert-manager.

---

## 🗺️ Roadmap

| Stage | Status | Focus |
|-------|--------|-------|
| **1. Infrastructure** | ✅ | Terraform, VPC, EKS, IAM, API Gateway, Cognito |
| **2. Ingress** | ✅ | ingress-nginx, LoadBalancer, HTTP only |
| **3. Platform Services** | ⏳ | Nexus, SonarQube, Argo CD |
| **4. Microservices** | ✅ | Voting App, Helm chart |
| **5. CI Pipeline** | ⏳ | Azure DevOps (configure in console) |
| **6. CD Pipeline** | ⏳ | GitOps with Argo CD |
| **7. Secrets** | ⏳ | HashiCorp Vault |
| **8. Observability** | ⏳ | Datadog, MongoDB Atlas |

---

## 🛠️ Tech Stack

**Infrastructure:** Terraform, AWS (VPC, EKS, IAM, API Gateway, Cognito, S3)  
**Orchestration:** Kubernetes, Helm  
**Application:** Python/Flask (vote), Node.js (result), .NET (worker), Redis, MongoDB Atlas  
**Ingress:** ingress-nginx, HTTP; TLS at API Gateway only  
**CI/CD:** Azure DevOps (pipelines configured manually), Argo CD (planned)

---

## 🚀 Quick Start (high level)

1. **Provision cluster**  
   See [terraform/README.md](terraform/README.md): `terraform init` → `plan` → `apply` with **api_integration_uri = null** first. Capture **api_gateway_endpoint**.

2. **Configure kubectl**  
   `aws eks update-kubeconfig --name <cluster-name> --region <region>`

3. **Deploy ingress-nginx**  
   Confirm NLB DNS name; backend runs HTTP only.

4. **Wire API Gateway to NLB**  
   Set **api_integration_uri = http://&lt;nlb-dns&gt;** and run `terraform apply` again.

5. **Build and push images**  
   Build from **voting-app/vote**, **voting-app/result**, **voting-app/worker**, push to your registry (ACR/ECR).

6. **Deploy the app**  
   From repo root: set image registry in values, then  
   `helm upgrade --install voting-app ./helm-charts --values ./helm-charts/values-nonprod.yaml`

7. **Create MongoDB secret**  
   Create the `mongodb-atlas-credentials` secret in the cluster as described in [helm-charts/README.md](helm-charts/README.md).

---

## 📊 Architecture

**Current (minimal setup):**
```
AWS Cloud
└── VPC (Multi-AZ)
    ├── Public Subnets (IGW, NAT)
    ├── Private Subnets (EKS nodes, EKS LB discovery tags)
    └── EKS Cluster
        ├── Managed Node Groups
        ├── Addons (CNI, DNS, proxy, EBS CSI)
        └── Voting App (Helm)
            ├── ingress-nginx (LoadBalancer → NLB, HTTP)
            ├── vote, result (HTTP)
            ├── worker, redis (ClusterIP)
API Gateway (HTTP API, $default stage)
  → JWT (Cognito) → NLB → ingress-nginx → Services
```

---

## 📚 Documentation Index

- **[README.md](README.md)** (this file) — Guide and structure
- **[terraform/README.md](terraform/README.md)** — Infrastructure, apply flow, variables
- **[voting-app/README.md](voting-app/README.md)** — Application source and build context
- **[helm-charts/README.md](helm-charts/README.md)** — Helm chart: local (Minikube) vs EKS

---

## 📝 Changelog

**January 31, 2026**
- Minimal setup: removed ACM, Route53, API Gateway custom domain, cert-manager
- API Gateway HTTP API with default HTTPS endpoint; Cognito + JWT authorizer
- Ingress HTTP only; TLS only at API Gateway
- Terraform modules: networking, iam, eks, irsa; apply flow (api_integration_uri in two steps)

**January 29, 2026**
- Stage 1 complete: Infrastructure foundation
- Terraform modules for VPC, IAM, EKS; multi-environment; remote state (S3)
- Voting App and Helm chart; linked README structure

---

_Last Updated: January 31, 2026 | Main README as guide_
