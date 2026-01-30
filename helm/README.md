# Voting App — Helm Chart

> **Deployment** for the [Voting App](voting-app/README.md) on Kubernetes (EKS or Minikube).  
> Part of the [Cloud-Native DevOps Platform](../README.md).

This chart deploys **vote**, **result**, **worker**, and **redis**. Application source and build context live in **[voting-app/](../voting-app/README.md)**. Infrastructure is provisioned with **[terraform/](../terraform/README.md)**.

---

## 📖 Overview

| Component | Description |
|-----------|-------------|
| **Vote** | Python/Flask frontend for submitting votes → talks to Redis |
| **Result** | Node.js backend for real-time results → talks to MongoDB Atlas |
| **Worker** | .NET background worker: Redis → MongoDB Atlas |
| **Redis** | In-memory queue (in-cluster) |
| **MongoDB Atlas** | External; connection via Kubernetes secret |

---

## When to use which values file

| Use case | Values file | Notes |
|----------|-------------|--------|
| **Local testing (Minikube)** | `values-minikube.yaml` | NodePort, sample vote/result images; worker/result need your images or use as-is for UI only |
| **Deployed (nonprod / EKS)** | `values-nonprod.yaml` | Set image registry (ACR/ECR); LoadBalancer |
| **Deployed (production)** | `values-prod.yaml` | Higher replicas/resources; optional Ingress |

All deployment paths (local or pipeline) use the **same chart** in **helm/**; only the values file and image registry differ.

---

## Prerequisites

- **Kubernetes cluster** (EKS from [terraform](../terraform/README.md), or Minikube for local)
- **Helm 3.x**
- **kubectl** configured for the cluster
- **MongoDB Atlas** connection string (for worker and result)
- **Container images** (for deployed use): build from [voting-app/](../voting-app/README.md) and push to your registry (ACR/ECR)

---

## Installation

### 1. Create MongoDB secret

```bash
MONGODB_URI="mongodb+srv://user:pass@cluster.mongodb.net/?retryWrites=true&w=majority"

kubectl create secret generic mongodb-atlas-credentials \
  --from-literal=connection-string="$MONGODB_URI" \
  --namespace default
```

### 2. Set image registry (deployed use)

Edit **values.yaml** or the environment-specific file (`values-nonprod.yaml` / `values-prod.yaml`) and set your registry:

```yaml
image:
  vote:
    repository: <YOUR_REGISTRY>/voting-app-vote   # e.g. myacr.azurecr.io/voting-app-vote
  worker:
    repository: <YOUR_REGISTRY>/voting-app-worker
  result:
    repository: <YOUR_REGISTRY>/voting-app-result
```

For **local Minikube**, `values-minikube.yaml` already uses sample vote/result images; you can leave or override as needed.

### 3. Install or upgrade the chart

**From repository root** (`cloud-native-devops-platform/`).

**Non-production (EKS / deployed):**
```bash
helm upgrade --install voting-app ./helm \
  --values ./helm/values-nonprod.yaml \
  --namespace default \
  --create-namespace
```

**Production:**
```bash
helm upgrade --install voting-app ./helm \
  --values ./helm/values-prod.yaml \
  --namespace production \
  --create-namespace
```

**Local (Minikube):**
```bash
minikube start
helm upgrade --install voting-app ./helm --values ./helm/values-minikube.yaml
minikube service voting-app-vote
minikube service voting-app-result
```

---

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount.vote` | Vote pod replicas | `2` |
| `replicaCount.worker` | Worker pod replicas | `2` |
| `replicaCount.result` | Result pod replicas | `2` |
| `mongodb.secretName` | Secret with MongoDB URI | `mongodb-atlas-credentials` |
| `mongodb.secretKey` | Key in secret | `connection-string` |
| `service.vote.type` | Vote service type | `LoadBalancer` (nonprod/prod) |
| `service.result.type` | Result service type | `LoadBalancer` |
| `ingress.enabled` | Enable Ingress | `false` (true in values-prod if desired) |

---

## Verifying installation

```bash
kubectl get pods -l app.kubernetes.io/name=voting-app
kubectl get svc -l app.kubernetes.io/name=voting-app

# LoadBalancer hosts (EKS)
kubectl get svc voting-app-vote -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc voting-app-result -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

kubectl logs -l app.kubernetes.io/component=worker --tail=50
kubectl logs -l app.kubernetes.io/component=result --tail=50
```

---

## Uninstall

```bash
helm uninstall voting-app --namespace default
```

---

## Troubleshooting

**Worker can’t connect to MongoDB**  
- Check secret: `kubectl get secret mongodb-atlas-credentials -o jsonpath='{.data.connection-string}' | base64 -d`  
- Ensure MongoDB Atlas network access allows your EKS NAT / egress IPs.

**Wrong or missing images**  
- For deployed use, set `image.*.repository` and `image.*.tag` in the chosen values file (or override with `--set`).  
- Images are built from [voting-app/vote](../voting-app/vote), [voting-app/result](../voting-app/result), [voting-app/worker](../voting-app/worker).

---

## 📚 Documentation

- [Main README](../README.md) — Platform guide and structure
- [Voting App source](../voting-app/README.md) — vote, result, worker build context
- [Terraform](../terraform/README.md) — EKS provisioning

---

_Helm chart for Voting App — local (Minikube) and deployed (EKS)._
