# Vault Environment Infrastructure

This repository contains Terraform configuration for managing HashiCorp Vault environments with automated deployment via GitHub Actions.

## Overview

This infrastructure automatically provisions:
- **KV v2 Secret Engines** for multiple environments (staging, prod, dev)
- **SSH Key Pairs** stored securely in Vault
- **AppRole Authentication** for GitHub Actions integration
- **Vault Policies** for controlled access

## Prerequisites

- HashiCorp Vault server (running and accessible)
- Terraform Cloud account with workspace configured
- GitHub repository with Actions enabled

## Configuration

### Terraform Cloud

The project uses Terraform Cloud for state management. Configure your workspace in `main.tf`:

```hcl
terraform {
  cloud {
    organization = "gcp-live"
    workspaces {
      name = var.tfc_workspace
    }
  }
}
```

### GitHub Secrets

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

**Required Secrets:**
- `TF_API_TOKEN` - Terraform Cloud API token
- `VAULT_ADDR` - Vault server URL (e.g., `https://vault.example.com:8200`)
- `VAULT_TOKEN` - Vault admin token for Terraform operations
- `VAULT_ROLE_ID` - AppRole role ID for GitHub Actions (from Terraform output)
- `VAULT_SECRET_ID` - AppRole secret ID for GitHub Actions (from Terraform output)

**Required Variables:**
- `TFC_WORKSPACE` - Terraform Cloud workspace name

### Environments

The default environments are defined in `variable.tf`:
- `staging`
- `prod`
- `dev`

## Deployment

### Manual Deployment

Run Terraform locally:

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### GitHub Actions Deployment

The workflow can be triggered:

1. **Manually** via workflow_dispatch:
   - Go to Actions → Full Infrastructure Deploy with Vault
   - Click "Run workflow"
   - Select environment and action (apply/plan)

2. **Automatically** on push to `main` branch (runs apply by default)

## Getting AppRole Credentials

After initial deployment, retrieve the AppRole credentials:

```bash
# Get role IDs
terraform output github_actions_role_ids

# Get secret IDs (sensitive)
terraform output -json github_actions_secret_ids
```

Add these to your GitHub Secrets as `VAULT_ROLE_ID` and `VAULT_SECRET_ID`.

## Vault Integration in Pipelines

The GitHub Actions workflow automatically authenticates to Vault and retrieves secrets:

```yaml
- name: Import Secrets from Vault
  uses: hashicorp/vault-action@v3
  with:
    url: ${{ secrets.VAULT_ADDR }}
    method: approle
    roleId: ${{ secrets.VAULT_ROLE_ID }}
    secretId: ${{ secrets.VAULT_SECRET_ID }}
    secrets: |
      staging/ssh-keys public_key | SSH_PUBLIC_KEY ;
      staging/ssh-keys private_key | SSH_PRIVATE_KEY
```

Retrieved secrets are available as environment variables in subsequent steps.

## Resources Created

For each environment, Terraform creates:

1. **KV Secret Engine** (`vault_mount.kv`)
   - Path: `{environment}` (e.g., `staging`, `prod`)
   - Type: KV v2

2. **SSH Key Pair** (`vault_generic_secret.ssh_keypair`)
   - Stored at: `{environment}/ssh-keys`
   - Contains: `public_key`, `private_key`

3. **Vault Policy** (`vault_policy.github_actions_policy`)
   - Name: `{environment}-github-actions-policy`
   - Grants read access to SSH keys

4. **AppRole** (`vault_approle_auth_backend_role.github_actions`)
   - Role: `github-actions-{environment}`
   - Token TTL: 10 minutes
   - Token Max TTL: 20 minutes

5. **AppRole Credentials** (`vault_generic_secret.github_actions_credentials`)
   - Stored at: `{environment}/github-actions`
   - Contains: `role_id`, `secret_id`

## Workflow Features

- **Environment Selection**: Choose staging or production
- **Action Selection**: Run plan or apply
- **Auto-approve**: Apply runs automatically without confirmation
- **Vault Integration**: Automatically retrieves secrets for each pipeline run

## Security Considerations

- AppRole secret IDs are marked as sensitive in Terraform outputs
- GitHub Actions secrets are encrypted at rest
- Vault tokens have limited TTL (10-20 minutes)
- Policies follow least-privilege access principles

## Troubleshooting

### Terraform Cloud Authentication Failed
- Verify `TF_API_TOKEN` is correct
- Check workspace name matches `TFC_WORKSPACE` variable

### Vault Authentication Failed
- Verify `VAULT_ADDR` is accessible
- Check `VAULT_TOKEN` has admin permissions
- Ensure `VAULT_ROLE_ID` and `VAULT_SECRET_ID` match Terraform outputs

### Secrets Not Found
- Verify AppRole has correct policy attached
- Check secret paths match environment names
- Ensure secrets were created by Terraform apply

## License

This project is private and proprietary.
