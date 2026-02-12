# ☸️ Kubernetes Platform Config

Platform-level manifests and Helm values consumed by the platform deployment pipeline.

## 🗂️ Files

| File | Purpose |
| --- | --- |
| `argocd-values.yaml` | Argo CD server path/baseHref settings (`/api/argocd`) |
| `sonarqube-values.yaml` | SonarQube web context (`/api/sonarqube`) |
| `external-secrets-values.yaml` | External Secrets chart values |
| `datadog-agent.yaml` | DatadogAgent CR template |
| `healthz.yaml` | Lightweight health endpoint deployment/service |
| `ingress-argocd.yaml` | Internal ALB ingress for Argo CD and `/healthz` |
| `ingress-sonarqube.yaml` | Internal ALB ingress for SonarQube |
| `ingress-nexus.yaml` | Internal ALB ingress and service/endpoints for Nexus |
| `ingress-vault.yaml` | Internal ALB ingress and service/endpoints for Vault |
| `vault-k8s-auth-reviewer.yaml` | Service account/token/binding for Vault Kubernetes auth |
| `external-secrets-vault-store.yaml` | ClusterSecretStore for Vault backend |
| `external-secrets-voting-app.yaml` | ExternalSecret objects for app pull/Mongo secrets |

## 🧩 Placeholders Rendered by Pipeline

- `__ALB_NAME__` in ingress manifests (`nonprod-alb` or `prod-alb`)
- `__CLUSTER_NAME__` and `__DATADOG_SITE__` in `datadog-agent.yaml`

## 🧪 Applied By

`azure-pipelines-helm.yml` applies these resources after deploying Helm charts for platform tools.

## 🛠️ Manual Apply Example

```bash
kubectl apply -f k8s-config/healthz.yaml
sed "s/__ALB_NAME__/nonprod-alb/g" k8s-config/ingress-argocd.yaml | kubectl apply -f -
sed "s/__ALB_NAME__/nonprod-alb/g" k8s-config/ingress-sonarqube.yaml | kubectl apply -f -
```

## 📝 Notes

- `ingress-nexus.yaml` and `ingress-vault.yaml` currently point to fixed private IP `172.30.2.117` via `Endpoints` objects.
- External Secrets expects Vault auth and KV paths to be available exactly as configured.
