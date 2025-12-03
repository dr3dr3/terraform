# Cross-Stack Reference Suggestions

> Analysis of opportunities to use `tfe_outputs` or `terraform_remote_state` for cross-stack references in the Terraform codebase.

**Date**: December 2, 2025

---

## Overview

Cross-stack references allow Terraform configurations to read output values from other Terraform state files. This enables:

- **Loose coupling** between infrastructure layers
- **Elimination of hardcoded values** like account IDs, role ARNs, and resource identifiers
- **Automatic updates** when upstream resources change
- **Better consistency** across environments

In Terraform Cloud, use `data "tfe_outputs"` to read outputs from another workspace.

---

## Current State Analysis

### Existing Cross-Stack References ✅

The following configuration already uses cross-stack references correctly:

| Workspace | References From | Purpose |
|-----------|-----------------|---------|
| `eks-cluster-admin` | `development-platform-eks`, `staging-platform-eks`, `production-platform-eks`, `sandbox-platform-eks` | Reads EKS cluster details (name, endpoint, ARN, OIDC issuer URL) for 1Password sync |

**Location**: `terraform/env-management/foundation-layer/eks-cluster-admin/main.tf`

```hcl
data "tfe_outputs" "eks_development" {
  count        = var.sync_development_eks ? 1 : 0
  organization = var.tfc_organization
  workspace    = var.eks_development_workspace
}
```

---

## Recommendations

### 1. Terraform Cloud Workspaces → Foundation Layer Roles

**Current State**: Hardcoded IAM role ARNs in workspace variable definitions.

**Location**: `terraform/env-management/foundation-layer/terraform-cloud/workspaces.tf`

**Hardcoded Values**:

```hcl
# Lines 74, 121
value = "arn:aws:iam::169506999567:role/terraform-cloud-oidc-role"

# Lines 277, 322
value = "arn:aws:iam::126350206316:role/terraform-dev-foundation-cicd-role"
```

**Suggestion**: Read these role ARNs from the workspaces that create them.

**Proposed Cross-Stack References**:

| Target Workspace | Source Workspace | Output to Reference |
|------------------|------------------|---------------------|
| `terraform-cloud` | `tfc-oidc-role` | `terraform_cloud_oidc_role_arn` |
| `terraform-cloud` | `dev-foundation-iam-roles-for-terraform` | `foundation_cicd_role_arn` |

**Benefits**:

- Role ARNs update automatically if role names change
- Eliminates duplication of account IDs
- Creates explicit dependency between workspaces

**Example Implementation**:

```hcl
# In terraform/env-management/foundation-layer/terraform-cloud/main.tf

data "tfe_outputs" "management_tfc_oidc" {
  organization = var.tfc_organization
  workspace    = "management-foundation-tfc-oidc-role"
}

data "tfe_outputs" "dev_foundation_iam_roles" {
  organization = var.tfc_organization
  workspace    = "development-foundation-iam-roles-for-terraform"
}

# Then use:
# data.tfe_outputs.management_tfc_oidc.values.terraform_cloud_oidc_role_arn
# data.tfe_outputs.dev_foundation_iam_roles.values.foundation_cicd_role_arn
```

**Note**: This creates a circular dependency concern since `terraform-cloud` creates the workspaces. Consider:

- Initial bootstrap with hardcoded values
- After first apply, switch to cross-stack references
- Or keep management-level OIDC role hardcoded as it rarely changes

---

### 2. IAM Roles for People → Account IDs

**Current State**: Account IDs passed as input variables (`additional_account_ids`, `non_production_account_ids`).

**Location**: `terraform/env-management/foundation-layer/iam-roles-for-people/`

**Current Approach**:

```hcl
variable "additional_account_ids" {
  type    = list(string)
  default = []
}
```

**Suggestion**: Read account IDs from the `tfc-oidc-role` or `iam-roles-for-terraform` workspaces in each environment.

**Proposed Cross-Stack References**:

| Source Workspace | Output | Purpose |
|------------------|--------|---------|
| `tfc-oidc-role` | `aws_account_id` | Management account ID |
| `dev-foundation-iam-roles-for-terraform` | `account_id` | Development account ID |
| (future) `staging-foundation-iam-roles` | `account_id` | Staging account ID |
| (future) `sandbox-foundation-iam-roles` | `account_id` | Sandbox account ID |

**Benefits**:

- Single source of truth for account IDs
- Easier to add new environments
- Prevents accidental misconfiguration

---

### 3. Development GHA-OIDC → Use OIDC Provider from Terraform Roles

**Current State**: Both `gha-oidc` and `iam-roles-for-terraform` create separate OIDC providers in the development account.

**Location**:

- `terraform/env-development/foundation-layer/gha-oidc/main.tf`
- `terraform/env-development/foundation-layer/iam-roles-for-terraform/main.tf`

**Issue**: AWS allows only ONE OIDC provider per identity provider URL per account. Currently, both configurations create:

- GitHub Actions OIDC provider (`token.actions.githubusercontent.com`)
- Terraform Cloud OIDC provider (`app.terraform.io`)

**Suggestion**: If these are meant to run in the same account, one should reference the other's OIDC provider output rather than creating duplicates.

**Proposed Cross-Stack Reference**:

```hcl
# If iam-roles-for-terraform runs first, gha-oidc could reference its outputs
# OR if gha-oidc runs first, iam-roles-for-terraform could reference its outputs
```

**Note**: Review whether these are intentionally separate or if one should depend on the other.

---

### 4. EKS Platform Layer → Foundation Layer VPC (Future)

**Current State**: The EKS Auto Mode configuration creates its own VPC inline.

**Location**: `terraform/env-development/platform-layer/eks-auto-mode/main.tf`

**Current Approach**: VPC is created within the same module:

```hcl
locals {
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 11)]
}
```

**Suggestion**: If you later separate networking into a foundation-layer VPC workspace, the EKS configuration should reference:

| Source Workspace | Outputs to Reference |
|------------------|---------------------|
| `development-foundation-vpc` (future) | `vpc_id`, `private_subnet_ids`, `public_subnet_ids` |

**Benefits**:

- Network configuration managed separately from compute
- Multiple EKS clusters could share the same VPC
- Network security managed in one place

---

### 5. GitHub Repository Configuration → AWS Account/Role Details

**Current State**: GitHub Actions workflow files need AWS role ARNs for OIDC authentication.

**Location**: `terraform/env-management/foundation-layer/github-dr3dr3/`

**Suggestion**: When configuring GitHub Actions secrets/variables via Terraform, reference the role ARNs from the OIDC workspaces.

**Proposed Cross-Stack References**:

| Source Workspace | Output | Use in GitHub |
|------------------|--------|---------------|
| `development-foundation-gha-oidc` | `github_actions_dev_platform_role_arn` | Actions secret `AWS_ROLE_ARN` |
| `development-platform-eks` | `cluster_name`, `cluster_endpoint` | Actions variable for deployment |

**Benefits**:

- GitHub Actions configuration automatically updates when roles change
- Single source of truth for AWS integration settings
- No manual copy-paste of ARNs

---

### 6. EKS Cluster Admin → Permission Set Names for aws-auth

**Current State**: The EKS cluster admin reads EKS cluster details from platform workspaces.

**Location**: `terraform/env-management/foundation-layer/eks-cluster-admin/`

**Enhancement Suggestion**: Also read IAM Identity Center permission set names to help generate aws-auth ConfigMap entries.

**Proposed Cross-Stack Reference**:

| Source Workspace | Outputs to Reference |
|------------------|---------------------|
| `iam-roles-for-people` | `admin_permission_set_name`, `platform_engineers_permission_set_name`, `developers_permission_set_name` |

**Benefits**:

- aws-auth ConfigMap entries generated from authoritative source
- Permission set changes automatically reflected
- Kubernetes RBAC aligned with AWS IAM Identity Center

---

### 7. Development IAM Roles → TFC OIDC Provider ARN

**Current State**: The development account's IAM roles configuration creates its own OIDC provider.

**Location**: `terraform/env-development/foundation-layer/iam-roles-for-terraform/main.tf`

**Current Approach**:

```hcl
resource "aws_iam_openid_connect_provider" "terraform_cloud" {
  url             = "https://${local.tfc_hostname}"
  client_id_list  = [local.tfc_audience]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}
```

**Suggestion**: For consistency, the thumbprint could be referenced from a shared configuration or the management account's output (though it's currently the same value everywhere).

**Note**: This is a lower priority since the thumbprint value is stable and standardized.

---

## Implementation Priority

| Priority | Recommendation | Effort | Impact |
|----------|---------------|--------|--------|
| **High** | 1. TFC Workspaces → Role ARNs | Medium | Eliminates hardcoded ARNs, prevents drift |
| **High** | 2. IAM for People → Account IDs | Low | Reduces configuration errors |
| **Medium** | 5. GitHub Config → AWS Details | Medium | Automates GitHub Actions setup |
| **Medium** | 6. EKS Admin → Permission Sets | Low | Improves aws-auth consistency |
| **Low** | 3. OIDC Provider Consolidation | High | May require refactoring |
| **Low** | 4. EKS → VPC (Future) | High | Only if VPC is separated |
| **Low** | 7. Thumbprint Reference | Low | Minimal benefit |

---

## Implementation Considerations

### Circular Dependencies

When workspace A creates workspace B, and workspace B's outputs are needed by workspace A:

1. **Bootstrap Phase**: Use hardcoded values for initial creation
2. **Migration Phase**: After both exist, add cross-stack references
3. **Steady State**: Cross-stack references maintain consistency

### Workspace Dependencies

Document workspace dependencies explicitly in a README or diagram:

```text
terraform-cloud (creates workspaces)
    ↓ reads from
tfc-oidc-role (creates OIDC role)
    ↓ reads from
iam-roles-for-terraform (creates layer-specific roles)
    ↓ reads from
eks-platform (creates EKS cluster)
    ↓ reads from
eks-cluster-admin (syncs to 1Password)
```

### Remote State Sharing

In Terraform Cloud, enable remote state sharing between workspaces that need to reference each other:

1. Go to the source workspace settings
2. Enable "Share state globally" or specify consumer workspaces
3. Use `tfe_workspace_settings` resource if managing via Terraform

Example:

```hcl
resource "tfe_workspace_settings" "tfc_oidc_role" {
  workspace_id              = tfe_workspace.tfc_oidc_role.id
  global_remote_state       = false
  remote_state_consumer_ids = [
    tfe_workspace.terraform_cloud.id,
  ]
}
```

---

## Summary

The codebase already demonstrates good use of cross-stack references in the `eks-cluster-admin` workspace. Extending this pattern to eliminate hardcoded role ARNs and account IDs will improve maintainability and reduce configuration drift.

**Key Actions**:

1. Add `tfe_outputs` data sources to read role ARNs from foundation workspaces
2. Configure remote state sharing permissions in Terraform Cloud
3. Document workspace dependency order
4. Consider consolidating OIDC provider creation to avoid duplication

---

**Related Documents**:

- [Terraform Best Practices](terraform-best-practices.md)
- [ADR-003: Infra Layering & Repository Structure](../reference/architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
- [ADR-009: Folder Structure](../reference/architecture-decision-register/ADR-009-folder-structure.md)
