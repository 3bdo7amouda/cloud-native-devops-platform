# Voting App Helm Chart

This chart deploys the Voting App into Kubernetes (EKS).

## Components

- `vote` (Flask): writes votes directly to MongoDB Atlas
- `result` (Node.js + Socket.IO): reads votes from MongoDB Atlas and shows live results
- `worker` (optional, legacy): disabled by default

## Namespace / Fargate

Deploy into namespace `voting-app`. The Terraform in this repo creates an EKS Fargate profile that selects `voting-app`, so pods in this namespace run on Fargate.

## Prerequisites

- AWS Load Balancer Controller installed in the cluster
- MongoDB Atlas connection string stored as a Kubernetes secret in `voting-app`

```bash
MONGODB_URI="mongodb+srv://user:pass@cluster.mongodb.net/?retryWrites=true&w=majority"

kubectl create namespace voting-app --dry-run=client -o yaml | kubectl apply -f -
kubectl -n voting-app create secret generic mongodb-atlas-credentials \
  --from-literal=connection-string="$MONGODB_URI"
```

## Ingress / Routes

When `ingress.enabled=true`, the chart creates an ALB Ingress routing:

- `/api/vote` -> `vote` service
- `/api/result` -> `result` service

The apps are configured with `BASE_PATH` so they serve under these prefixes (no ALB path rewrite required).

To share the same ALB as the platform tools, use the same ALB Ingress Group and load balancer name annotations (see `values-nonprod.yaml` and `values-prod.yaml`).

## Install (Manual Helm)

```bash
helm upgrade --install voting-app ./helm-charts \
  --namespace voting-app \
  --create-namespace \
  -f ./helm-charts/values-nonprod.yaml
```

## Values Files

- `helm-charts/values.yaml`: defaults (Ingress disabled)
- `helm-charts/values-nonprod.yaml`: enables ALB Ingress and targets `nonprod-alb`
- `helm-charts/values-prod.yaml`: enables ALB Ingress and targets `prod-alb`

## Verify

```bash
kubectl -n voting-app get deploy,svc,ingress
kubectl -n voting-app logs -l app.kubernetes.io/component=vote --tail=50
kubectl -n voting-app logs -l app.kubernetes.io/component=result --tail=50
```

