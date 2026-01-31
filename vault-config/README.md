# Vault configuration

Used by the Infra Pipeline (stage 7). Add a script or manifests to:

1. **Enable Kubernetes auth** – `vault auth enable kubernetes`
2. **Configure Kubernetes auth** – role, JWT path, service account
3. **Enable KV v2** – `vault secrets enable -path=kv kv-v2`
4. **Create policies** – e.g. read/write for apps
5. **Create roles** – link policies to Kubernetes service accounts

## Option A: Script

Create `configure-vault.sh` in this directory. The pipeline runs it when present. Use **VAULT_ADDR** and **VAULT_TOKEN** (or **VAULT_ROOT_TOKEN**) from a pipeline variable group so the script can authenticate.

## Option B: Manifests / Jobs

Add Kubernetes Jobs or ConfigMaps that run Vault CLI or Terraform to configure Vault. Reference this directory from the pipeline if you switch to an apply-based flow.
