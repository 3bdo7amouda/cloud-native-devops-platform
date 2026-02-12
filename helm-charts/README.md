# Voting App Helm Chart

Helm chart for deploying the voting application workloads on Kubernetes.

## Components

- `vote` deployment and service (Flask)
- `result` deployment and service (Node.js + Socket.IO)
- `worker` deployment (disabled by default)
- Optional shared ALB ingress for `/api/vote` and `/api/result`

## Namespace

Deploy into namespace `voting-app`. Terraform provisions a Fargate profile targeting this namespace.

## Required Secrets

The chart expects these secrets in namespace `voting-app`:
- `nexus-pull` (`kubernetes.io/dockerconfigjson`) for private image pulls
- `mongodb-atlas-credentials` with key `connection-string`

These are normally created by External Secrets via manifests in `k8s-config/`.

## Templates

`helm-charts/templates/` contains:
- `_helpers.tpl`: shared naming and labels
- `vote-deployment.yaml`, `vote-service.yaml`
- `result-deployment.yaml`, `result-service.yaml`
- `worker-deployment.yaml` (only when `worker.enabled=true`)
- `ingress.yaml` (only when `ingress.enabled=true`)

Notes:
- Resource names are generated with `{{ include "voting-app.fullname" . }}`.
- `vote` and `result` deployments set `BASE_PATH` environment variables to match ingress routes.

## Install

```bash
helm upgrade --install voting-app ./helm-charts \
  --namespace voting-app \
  --create-namespace \
  -f ./helm-charts/values-nonprod.yaml
```

## Upgrade with explicit image tag

```bash
helm upgrade --install voting-app ./helm-charts \
  --namespace voting-app \
  -f ./helm-charts/values-nonprod.yaml \
  --set image.vote.tag=<tag> \
  --set image.result.tag=<tag> \
  --set image.worker.tag=<tag>
```

## Values Files

| File | Purpose |
| --- | --- |
| `values.yaml` | Base defaults (ingress disabled) |
| `values-nonprod.yaml` | Nonprod ingress annotations (`nonprod-alb`) |
| `values-prod.yaml` | Prod ingress annotations (`prod-alb`) |

## Important Values

- `worker.enabled` (`false` by default)
- `image.*.repository`, `image.*.tag`, `imagePullSecrets`
- `mongodb.secretName`, `mongodb.secretKey`, `mongodb.databaseName`
- `ingress.enabled`, `ingress.className`, `ingress.annotations`

## Verify

```bash
kubectl -n voting-app get deploy,svc,ingress
kubectl -n voting-app logs -l app.kubernetes.io/component=vote --tail=50
kubectl -n voting-app logs -l app.kubernetes.io/component=result --tail=50
```
