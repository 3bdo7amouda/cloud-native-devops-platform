# Kubernetes configuration

Applied by the Infra Pipeline (stage 6). Add manifests here for:

- **Namespaces** (optional; pipeline creates common ones)
- **Ingress resources with TLS** (e.g. Ingress objects with `spec.tls` and cert-manager or pre-created secrets)

The pipeline runs:

```bash
kubectl apply -f k8s-config/ -R
```

## External Secrets (stage 8)

Place **SecretStore**, **ClusterSecretStore**, and **ExternalSecret** manifests under:

```
k8s-config/external-secrets/
```

The pipeline applies them with:

```bash
kubectl apply -f k8s-config/external-secrets/ -R
```
