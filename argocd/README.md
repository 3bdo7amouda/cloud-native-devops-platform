# Argo CD Manifests

GitOps manifests used to register and sync the voting application in Argo CD.

## Layout

| Path | Purpose |
| --- | --- |
| `projects/voting-app.yaml` | AppProject with repo and destination restrictions |
| `apps/voting-app-nonprod.yaml` | Nonprod Application using `helm-charts/values-nonprod.yaml` |
| `apps/voting-app-prod.yaml` | Prod Application using `helm-charts/values-prod.yaml` |

## Project Configuration

`projects/voting-app.yaml` restricts:
- Source repository to `https://github.com/3bdo7amouda/cloud-native-devops-platform.git`
- Destination namespace to `voting-app`
- Destination cluster to in-cluster Kubernetes API

## Application Configuration

Both app manifests target:
- Repo: `https://github.com/3bdo7amouda/cloud-native-devops-platform.git`
- Path: `helm-charts`
- Namespace: `voting-app`
- Release name: `voting-app`

Environment difference:
- `apps/voting-app-nonprod.yaml` uses `values-nonprod.yaml`
- `apps/voting-app-prod.yaml` uses `values-prod.yaml`

Sync policy in both apps:
- `automated.prune: true`
- `automated.selfHeal: true`
- `syncOptions: CreateNamespace=true`

## Pipeline Integration

`azure-pipelines-cd.yml`:
1. Updates kubeconfig for `${env}-eks`
2. Waits for Argo CD CRDs
3. Applies AppProject
4. Applies environment-specific Application

## Manual Apply

```bash
kubectl apply -f argocd/projects/voting-app.yaml
kubectl apply -f argocd/apps/voting-app-nonprod.yaml
```
