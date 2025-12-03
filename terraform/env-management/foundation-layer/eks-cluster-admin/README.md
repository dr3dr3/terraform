# EKS Cluster Admin

This Terraform configuration syncs EKS cluster connection details to 1Password, implementing **Phase 1.2** of [ADR-016](../../../../docs/reference/architecture-decision-register/ADR-016-eks-credentials-cross-repo-access.md).

Per [ADR-017](../../../../docs/reference/architecture-decision-register/ADR-017-eks-1password-lifecycle-coordination.md), this configuration is automatically triggered by GitHub Actions workflows to coordinate the lifecycle between EKS clusters and their 1Password secure notes.

## Purpose

Enable secure access to EKS clusters from a separate admin repository (devcontainer) by storing non-sensitive cluster connection details in 1Password. This allows:

- **Centralized cluster discovery**: All EKS cluster endpoints are stored in one place
- **No secret exposure**: Only connection metadata is stored, not credentials
- **Dynamic authentication**: Uses AWS SSO for authentication (no stored credentials)
- **Multi-cluster support**: Easy switching between development, staging, and production clusters
- **Automatic lifecycle management**: 1Password items are created/destroyed with EKS clusters (ADR-017)

## What Gets Synced

Per ADR-016, only non-sensitive cluster connection details are stored:

| Field | Description | Stored in 1Password |
|-------|-------------|---------------------|
| `cluster_name` | Name of the EKS cluster | ✅ Yes |
| `cluster_endpoint` | API server endpoint URL | ✅ Yes |
| `cluster_region` | AWS region | ✅ Yes |
| `aws_account_id` | AWS account containing the cluster | ✅ Yes |
| `cluster_arn` | Full ARN of the cluster | ✅ Yes |
| `oidc_provider_url` | OIDC issuer URL for IRSA | ✅ Yes |
| Cluster CA data | Certificate authority | ❌ No (retrieved via AWS API) |
| AWS credentials | Access keys/tokens | ❌ No (use SSO) |

## Prerequisites

1. **1Password Service Account**: Create a service account with write access to the target vault
2. **Terraform Cloud Workspace**: Create the `management-foundation-eks-cluster-admin` workspace
3. **EKS Cluster Deployed**: At least one EKS cluster must exist with Terraform state in TFC

## Configuration

### Authentication

This workspace uses the 1Password Terraform provider with a **Service Account Token**. The token is passed via the `onepassword_service_account_token` variable, which can be set via:

- `TF_VAR_onepassword_service_account_token` environment variable (recommended)
- `-var="onepassword_service_account_token=..."` command line flag
- `terraform.tfvars` file (NOT recommended for sensitive values)

**Prerequisites:**

1. Create a [Service Account](https://developer.1password.com/docs/service-accounts/) with access to the target vault
2. Note the service account token (`ops_...`)

**Local Development:**

```bash
# Set the environment variable
export TF_VAR_onepassword_service_account_token="ops_..."

# Run Terraform
cd terraform/env-management/foundation-layer/eks-cluster-admin
terraform init
terraform plan
terraform apply
```

**GitHub Actions:**

The `OP_SERVICE_ACCOUNT_TOKEN` secret is automatically passed to Terraform via `TF_VAR_onepassword_service_account_token` in the reusable workflow.

### Terraform Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and configure:

```hcl
# Enable/disable sync per environment
sync_development_eks = true
sync_staging_eks     = false
sync_production_eks  = false
sync_sandbox_eks     = false

# AWS account IDs
aws_account_id_development = "123456789012"
```

## Usage

### Initial Setup

1. Create the 1Password vault named "terraform" (or update `onepassword_vault_name`)

2. Create a 1Password service account with access to the vault

3. Set up the environment:

   ```bash
   export TF_VAR_onepassword_service_account_token="ops_..."
   ```

4. Run Terraform:

   ```bash
   cd terraform/env-management/foundation-layer/eks-cluster-admin
   terraform init
   terraform plan
   terraform apply
   ```

### Adding New Clusters

1. Enable the sync toggle for the environment:

   ```hcl
   sync_staging_eks = true
   ```

2. Set the AWS account ID:

   ```hcl
   aws_account_id_staging = "987654321098"
   ```

3. Run `terraform apply`

### Consuming Cluster Details

From the eks-admin devcontainer:

```bash
# Read cluster details from 1Password
CLUSTER_NAME=$(op read "op://terraform/EKS-development-dev-eks/cluster_name")
CLUSTER_REGION=$(op read "op://terraform/EKS-development-dev-eks/cluster_region")

# Update kubeconfig
aws eks update-kubeconfig --region $CLUSTER_REGION --name $CLUSTER_NAME
```

## Architecture

```text
┌─────────────────────────────┐
│   EKS Clusters (TFC State)  │
│  ┌─────────────────────────┐│
│  │ development-platform-eks││
│  │ staging-platform-eks    ││
│  │ production-platform-eks ││
│  └─────────────────────────┘│
└──────────────┬──────────────┘
               │
               │ data.tfe_outputs
               ▼
┌─────────────────────────────┐
│  eks-cluster-admin         │
│  (This Terraform Config)    │
└──────────────┬──────────────┘
               │
               │ onepassword_item
               ▼
┌─────────────────────────────┐
│       1Password Vault       │
│        "terraform"          │
│  ┌─────────────────────────┐│
│  │ EKS-development-*       ││
│  │ EKS-staging-*           ││
│  │ EKS-production-*        ││
│  └─────────────────────────┘│
└──────────────┬──────────────┘
               │
               │ op read
               ▼
┌─────────────────────────────┐
│     eks-admin Devcontainer  │
│  ┌─────────────────────────┐│
│  │ kubectl                 ││
│  │ k9s                     ││
│  │ helm                    ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

## Lifecycle Coordination (ADR-017)

Per ADR-017, this configuration uses **conditional resource counts** to automatically manage 1Password items based on EKS cluster existence:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EKS Cluster Lifecycle                               │
└─────────────────────────────────────────────────────────────────────────────┘

  Manual Trigger                    TTL Expiration
  (workflow_dispatch)               (eks-ttl-check.yml)
         │                                 │
         ▼                                 ▼
┌─────────────────┐              ┌─────────────────┐
│  terraform-dev- │              │  eks-ttl-check  │
│  platform-eks   │              │  workflow       │
└────────┬────────┘              └────────┬────────┘
         │                                │
    ┌────┴────┐                           │
    │         │                           │
    ▼         ▼                           ▼
┌───────┐ ┌───────┐              ┌───────────────┐
│ Apply │ │Destroy│              │ TTL Destroy   │
└───┬───┘ └───┬───┘              └───────┬───────┘
    │         │                          │
    └────┬────┘                          │
         │                               │
         ▼                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    reusable-1password-eks-sync.yml                          │
│                                                                             │
│  1. Checkout repository                                                     │
│  2. Install 1Password CLI                                                   │
│  3. terraform init (eks-cluster-admin)                                      │
│  4. terraform apply                                                         │
│     - If cluster exists → Creates/Updates 1Password item                    │
│     - If cluster gone → Destroys 1Password item (count = 0)                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### How It Works

1. **Cluster Existence Check**: The `locals.tf` file checks if the EKS cluster exists by reading TFC outputs:

   ```hcl
   dev_cluster_exists = (
     var.sync_development_eks &&
     length(data.tfe_outputs.eks_development) > 0 &&
     try(data.tfe_outputs.eks_development[0].values.cluster_name, "") != ""
   )
   ```

2. **Conditional Resource Creation**: 1Password items use the existence check for their count:

   ```hcl
   resource "onepassword_item" "eks_development" {
     count = local.dev_cluster_exists ? 1 : 0
     # ...
   }
   ```

3. **Automatic Cleanup**: When an EKS cluster is destroyed:
   - TFC outputs become empty
   - `local.dev_cluster_exists` becomes `false`
   - Resource count becomes `0`
   - Terraform destroys the 1Password item

### GitHub Actions Integration

The following workflows call the reusable sync workflow:

| Workflow | When Called | Effect |
|----------|-------------|--------|
| `terraform-dev-platform-eks.yml` | After apply or destroy | Creates or removes 1Password item |
| `eks-ttl-check.yml` | After TTL-based destroy | Removes orphaned 1Password item |

### Required GitHub Secrets

Add these secrets to your GitHub repository:

- `OP_SERVICE_ACCOUNT_TOKEN`: 1Password Service Account token with access to the vault
- `TF_API_TOKEN`: Terraform Cloud API token (may already exist)

## Files

| File | Purpose |
|------|---------|
| `backend.tf` | Terraform Cloud backend configuration |
| `main.tf` | 1Password items for each EKS cluster |
| `variables.tf` | Input variable definitions |
| `locals.tf` | Local values extracting EKS outputs |
| `outputs.tf` | Output values for verification |
| `terraform.tfvars.example` | Example variable values |

## Related ADRs

- [ADR-014](../../../../docs/reference/architecture-decision-register/ADR-014-terraform-cloud-workspace-triggers.md): Terraform Cloud workspace triggers (CLI-driven)
- [ADR-016](../../../../docs/reference/architecture-decision-register/ADR-016-eks-credentials-cross-repo-access.md): EKS cluster credentials and cross-repo access
- [ADR-017](../../../../docs/reference/architecture-decision-register/ADR-017-eks-1password-lifecycle-coordination.md): EKS and 1Password lifecycle coordination

## Troubleshooting

### "Vault not found" Error

Ensure the vault name matches exactly (case-sensitive) and the service account has access.

### "Workspace outputs not available"

The source EKS workspace must have at least one successful apply. Check that outputs are defined and not marked as sensitive.

### "Permission denied" from 1Password

The service account token may be expired or lack write permissions to the vault.
