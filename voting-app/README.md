# Voting App — Application Source

> **Microservices source** for the Voting App deployed via [Helm](../helm/README.md).  
> Part of the [Cloud-Native DevOps Platform](../README.md).

This directory contains the three services that make up the Voting App. Each subdirectory is the **Docker build context** for its image; the [Helm chart](../helm/README.md) deploys those images on Kubernetes (EKS or Minikube). Infrastructure is provisioned with [Terraform](../terraform/README.md).

---

## 📂 Structure

```
voting-app/
├── README.md       # This file
├── vote/           # Python/Flask — voting UI (build context for vote image)
├── result/         # Node.js — results UI (build context for result image)
└── worker/         # .NET — background worker (build context for worker image)
```

| Service | Stack | Role | Image name (in Helm) |
|---------|--------|------|----------------------|
| **vote** | Python 3.11, Flask, Gunicorn | Web UI for casting votes; writes to Redis | `voting-app-vote` |
| **result** | Node.js 18, Express | Web UI for results; reads from MongoDB Atlas | `voting-app-result` |
| **worker** | .NET 7 | Consumes votes from Redis, writes to MongoDB Atlas | `voting-app-worker` |

---

## Data flow

1. **Vote** (vote) → user submits vote → stored in **Redis**
2. **Worker** (worker) → reads from Redis → writes to **MongoDB Atlas**
3. **Result** (result) → reads from MongoDB Atlas → real-time results UI

Redis is deployed in-cluster by the Helm chart; MongoDB Atlas is external (connection string in a Kubernetes secret).

---

## Build context (for CI/CD or local)

When building container images, use each service directory as the **build context** and its **Dockerfile** inside that directory:

| Image | Dockerfile | Build context |
|-------|------------|----------------|
| vote | `voting-app/vote/Dockerfile` | `voting-app/vote` |
| result | `voting-app/result/Dockerfile` | `voting-app/result` |
| worker | `voting-app/worker/Dockerfile` | `voting-app/worker` |

Example (from repo root):

```bash
docker build -t voting-app-vote:latest -f voting-app/vote/Dockerfile voting-app/vote
docker build -t voting-app-result:latest -f voting-app/result/Dockerfile voting-app/result
docker build -t voting-app-worker:latest -f voting-app/worker/Dockerfile voting-app/worker
```

In Azure DevOps (or any pipeline), point the Docker build step to these paths; then push to your registry (ACR/ECR) and set the image repository and tag in the [Helm values](../helm/README.md).

---

## Local development (optional)

- **vote:** `cd vote && pip install -r requirements.txt && python app.py` (or use Dockerfile `dev` stage)
- **result:** `cd result && npm install && node server.js`
- **worker:** `cd worker && dotnet run`

For full app deployment (including Redis and wiring), use the [Helm chart](../helm/README.md) (e.g. with `values-minikube.yaml` for Minikube).

---

## 📚 Documentation

- [Main README](../README.md) — Platform guide and linked structure
- [Helm chart](../helm/README.md) — Deploy vote, result, worker, Redis; local vs deployed
- [Terraform](../terraform/README.md) — EKS provisioning

---

_Voting App source — build context for vote, result, worker images._
