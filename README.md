# 🚀 Cloud-Native DevOps Platform

End-to-end DevOps platform for running a microservices voting application on AWS EKS using Terraform, Azure DevOps pipelines, Helm, and Argo CD.

## ✨ Overview

This repository provides:
- Infrastructure as Code for networking, IAM, EKS, IRSA, API Gateway, and Cognito.
- CI/CD pipelines for infrastructure, platform tooling, application images, and GitOps deployment.
- Helm chart and Kubernetes configuration for platform services and the voting application.
- Application source code for `vote` (Flask), `result` (Node.js), and `worker` (.NET, optional).

## 🧭 Architecture Summary

Traffic and control flow:
- API Gateway HTTP API routes `/api/*`, `/auth/*`, and `/*` to an internal NLB via VPC Link.
- The NLB forwards to the shared internal ALB created by the AWS Load Balancer Controller.
- The ALB routes to platform tools (Argo CD, SonarQube, Nexus, Vault) and the voting app.
- The voting app runs in `voting-app` namespace, which is targeted by an EKS Fargate profile.

Key base paths served behind the ALB:
- `vote`: `/api/vote`
- `result`: `/api/result`
- Argo CD UI: `/api/argocd`
- SonarQube: `/api/sonarqube`
- Nexus proxy: `/api/nexus`
- Vault proxy: `/api/vault`

## 🗂️ Repository Structure

| Path | Purpose |
| --- | --- |
| `terraform/` | Terraform root module for AWS infrastructure |
| `helm-charts/` | Helm chart for the voting application |
| `k8s-config/` | Platform manifests and Helm values overlays |
| `argocd/` | Argo CD AppProject and Application manifests |
| `voting-app/` | Application source code and service Dockerfiles |
| `azure-pipelines-infra.yml` | Terraform pipeline |
| `azure-pipelines-helm.yml` | Platform tooling pipeline |
| `azure-pipelines-CI.yml` | Application CI pipeline (build, quality, scans) |
| `azure-pipelines-cd.yml` | Argo CD apply pipeline |

## 🌍 Environments

- `nonprod` and `prod` are supported by parameterized pipelines.
- Terraform inputs are provided via `nonprod.tfvars` (and optionally `prod.tfvars`).
- Helm uses `values-nonprod.yaml` and `values-prod.yaml` for ALB annotations and environment overrides.

## 🧪 Pipelines

| Pipeline | Purpose | Notes |
| --- | --- | --- |
| `azure-pipelines-infra.yml` | Terraform init/plan/apply | Parameter `env`, optional `destroy` |
| `azure-pipelines-helm.yml` | Install platform tools + apply k8s configs | Requires `DATADOG_API_KEY` |
| `azure-pipelines-CI.yml` | Build, scan, and push app images | Triggers on `voting-app/` path changes |
| `azure-pipelines-cd.yml` | Apply Argo CD project/app | Parameter `env` |

## 🧰 Platform Tooling (Helm Pipeline)

Installed and configured:
- AWS Load Balancer Controller
- Datadog Operator + DatadogAgent
- External Secrets
- Argo CD
- SonarQube

Applied manifests from `k8s-config/`:
- Ingresses for Argo CD, SonarQube, Nexus, Vault
- Health check deployment/service for ALB target group
- External Secrets configuration (Vault-backed)

## 🔐 Secrets and Registry

Required secrets in namespace `voting-app`:
- `nexus-pull` (`kubernetes.io/dockerconfigjson`) for private image pulls
- `mongodb-atlas-credentials` with key `connection-string`

These are normally created by External Secrets using Vault as the backend. The External Secrets setup lives in:
- `k8s-config/external-secrets-vault-store.yaml`
- `k8s-config/external-secrets-voting-app.yaml`

## 📈 Observability and Quality

- Datadog is deployed via Operator and `DatadogAgent` template in `k8s-config/datadog-agent.yaml`.
- SonarQube is deployed with the web context path `/api/sonarqube`.
- CI pipeline runs:
  - Gitleaks scan on the full repository
  - SonarQube scan for `voting-app`
  - Trivy image scans for `vote`, `result`, and `worker` images

## 🛡️ Security Highlights

- IRSA is used for AWS permissions (no static credentials in pods).
- EKS cluster access uses access entries and policies.
- Private subnets are used for cluster workloads.
- API Gateway and Cognito provide an optional edge authentication layer.

## ⚡ Quick Start (CLI)

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

### 2. Configure `kubectl`

```bash
aws eks update-kubeconfig --region us-east-1 --name nonprod-eks
kubectl get nodes
```

### 3. Deploy App via Helm (manual alternative to Argo CD)

```bash
helm upgrade --install voting-app ./helm-charts \
  --namespace voting-app \
  --create-namespace \
  -f ./helm-charts/values-nonprod.yaml
```

## 🔎 Operations

Common checks:

```bash
kubectl get ingress -A
kubectl -n voting-app get deploy,svc
kubectl -n voting-app logs -l app.kubernetes.io/component=vote --tail=50
kubectl -n voting-app logs -l app.kubernetes.io/component=result --tail=50
```

## 🧹 Cleanup

Terraform:

```bash
cd terraform
terraform destroy -var-file=nonprod.tfvars
```

Platform cleanup helper:

```bash
./cleanup-cluster.sh --confirm
```

## 📚 Documentation

- `terraform/README.md`
- `helm-charts/README.md`
- `k8s-config/README.md`
- `argocd/README.md`
- `voting-app/README.md`
