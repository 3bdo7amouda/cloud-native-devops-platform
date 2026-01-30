# Voting App Helm Chart

Kubernetes Helm chart for deploying the voting application with MongoDB Atlas on EKS.

## Architecture

- **Vote Service**: Python/Flask frontend for submitting votes
- **Worker Service**: .NET Core background worker processing votes from Redis to MongoDB
- **Result Service**: Node.js/Express backend displaying real-time results
- **Redis**: In-memory queue for vote submissions
- **MongoDB Atlas**: External managed database (third-party)

## Prerequisites

1. **Kubernetes Cluster**: EKS cluster running
2. **Helm 3.x**: Installed locally
3. **MongoDB Atlas**: Account and cluster created
4. **kubectl**: Configured to access your EKS cluster
5. **AWS CLI**: Configured with proper credentials
6. **Docker Images**: Built and pushed to ECR

## Installation

### 1. Create MongoDB Secret

```bash
# Replace with your actual MongoDB Atlas connection string
MONGODB_URI="mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority"

kubectl create secret generic mongodb-atlas-credentials \
  --from-literal=connection-string="$MONGODB_URI" \
  --namespace default
```

### 2. Update values.yaml

Edit `values.yaml` or environment-specific values files to set your ECR repository:

```yaml
image:
  vote:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/voting-app-vote
  worker:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/voting-app-worker
  result:
    repository: <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/voting-app-result
```

### 3. Install the Chart

**Non-Production:**
```bash
helm upgrade --install voting-app ./voting-app-helm \
  --values ./voting-app-helm/values-nonprod.yaml \
  --namespace default \
  --create-namespace
```

**Production:**
```bash
helm upgrade --install voting-app ./voting-app-helm \
  --values ./voting-app-helm/values-prod.yaml \
  --namespace production \
  --create-namespace
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount.vote` | Number of vote pods | `2` |
| `replicaCount.worker` | Number of worker pods | `2` |
| `replicaCount.result` | Number of result pods | `2` |
| `mongodb.secretName` | K8s secret containing MongoDB URI | `mongodb-atlas-credentials` |
| `mongodb.databaseName` | MongoDB database name | `voting` |
| `service.vote.type` | Vote service type | `LoadBalancer` |
| `service.result.type` | Result service type | `LoadBalancer` |
| `ingress.enabled` | Enable ingress | `false` |

## Verifying Installation

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=voting-app

# Check services
kubectl get svc -l app.kubernetes.io/name=voting-app

# Get LoadBalancer URLs
kubectl get svc voting-app-vote -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc voting-app-result -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check logs
kubectl logs -l app.kubernetes.io/component=worker --tail=50
kubectl logs -l app.kubernetes.io/component=result --tail=50
```

## Uninstalling

```bash
helm uninstall voting-app --namespace default
```

## Troubleshooting

### Worker can't connect to MongoDB
```bash
kubectl logs -l app.kubernetes.io/component=worker
# Check if MONGODB_URI secret is correct
kubectl get secret mongodb-atlas-credentials -o jsonpath='{.data.connection-string}' | base64 -d
```

### MongoDB Atlas Network Access
Ensure your EKS cluster's NAT Gateway IP is whitelisted in MongoDB Atlas Network Access settings.

## Development

To test locally with Minikube:
```bash
# Start minikube
minikube start

# Install chart
helm install voting-app ./voting-app-helm --values values-nonprod.yaml

# Access services
minikube service voting-app-vote
minikube service voting-app-result
```
