# Voting App — Application Source

This directory contains the application services for the Voting App. Kubernetes deployment is handled by the Helm chart in `helm-charts/`.

## Structure

```
voting-app/
├── vote/           Python/Flask voting UI (writes to MongoDB)
├── result/         Node.js results UI (reads from MongoDB)
└── worker/         Legacy worker (Redis-based, not used in the MongoDB-only setup)
```

## Data Flow (MongoDB-Only)

1. `vote` writes/updates the user vote in MongoDB Atlas (`voting.votes`)
2. `result` aggregates MongoDB votes and streams updates to the UI via Socket.IO

## Build Images

From repo root:

```bash
docker build -t voting-app-vote:latest -f voting-app/vote/Dockerfile voting-app/vote
docker build -t voting-app-result:latest -f voting-app/result/Dockerfile voting-app/result
```

## Runtime Configuration

Both services use:

- `MONGODB_URI`: MongoDB Atlas connection string
- `DATABASE_NAME`: defaults to `voting`

The Kubernetes chart also sets:

- `BASE_PATH=/api/vote` for `vote`
- `BASE_PATH=/api/result` for `result`

## Documentation

- `helm-charts/README.md` for deployment and Ingress routes
- `terraform/README.md` for EKS provisioning

