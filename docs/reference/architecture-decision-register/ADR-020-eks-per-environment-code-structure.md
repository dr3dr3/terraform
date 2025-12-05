# Architecture Decision Record: EKS Auto Mode Per-Environment Code Structure

## Status

Approved

## Context

The EKS Auto Mode Terraform configuration exists in separate folders for each environment:

- `/terraform/env-development/platform-layer/eks-auto-mode/`
- `/terraform/env-staging/platform-layer/eks-auto-mode/`
- `/terraform/env-production/platform-layer/eks-auto-mode/`

Each folder contains identical `.tf` files (`eks.tf`, `vpc.tf`, `iam.tf`, `kms.tf`, `main.tf`, `outputs.tf`, `variables.tf`, `backend.tf`) with environment-specific differences isolated to `terraform.tfvars`.

### Current Differences Between Environments

| Setting | Development | Staging | Production |
|---------|-------------|---------|------------|
| `vpc_cidr` | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| `az_count` | 2 | 2 | 3 |
| `single_nat_gateway` | true | false | false |
| `cloudwatch_log_retention_days` | 30 | 60 | 90 |
| `environment` | dev | stg | prod |
| `environment_tag` | Development | Staging | Production |

### Question Raised

Should the repeated Terraform code across environments be extracted into a reusable module in `terraform-modules/` to reduce duplication?

## Decision Drivers

- **Maintainability**: Effort required to keep environments in sync
- **Flexibility**: Ability to evolve environments independently
- **Blast radius**: Impact of changes on multiple environments
- **Complexity**: Cognitive load for understanding and debugging
- **Team workflow**: Alignment with Terraform Cloud workspace structure

## Options Considered

### Option 1: Keep Per-Environment Folders (Current State)

Maintain separate folders with identical `.tf` files, using `terraform.tfvars` for environment-specific values.

**Pros:**

- Clear isolation between environments
- No module versioning complexity
- Each environment can evolve independently if needed
- Direct alignment with Terraform Cloud workspace structure (per ADR-003)
- Simpler debugging - all code visible in one folder
- Blast radius limited to single environment per change
- No abstraction layer to understand

**Cons:**

- Duplicated `.tf` files across 3 folders
- Manual sync required when making structural changes
- Risk of environments drifting unintentionally

### Option 2: Create Shared Module

Extract common code to `terraform-modules/eks-auto-mode/` and have per-environment folders call the module.

```hcl
# terraform/env-development/platform-layer/eks-auto-mode/main.tf
module "eks" {
  source = "../../../terraform-modules/eks-auto-mode"
  
  environment     = "dev"
  vpc_cidr        = "10.0.0.0/16"
  az_count        = 2
  # ... other variables
}
```

**Pros:**

- Single source of truth for EKS configuration
- Changes automatically apply to all environments
- Reduced file count

**Cons:**

- Module versioning adds complexity
- Changes to module affect all environments simultaneously
- Harder to make environment-specific modifications
- Additional abstraction layer to understand
- Must coordinate module changes across environments
- Testing requires planning for all environments

### Option 3: Symlinks for Shared Files

Use symbolic links for files that must stay identical, keeping `terraform.tfvars` and `backend.tf` per-environment.

**Pros:**

- Files stay automatically in sync
- No module versioning

**Cons:**

- Symlinks can complicate Terraform Cloud VCS-driven workflows
- Git handling of symlinks varies across platforms
- Harder to understand at a glance
- Some tools don't follow symlinks properly

## Decision

**Option 1:** Keep Per-Environment Folders

Maintain the current structure with separate folders for each environment.

## Rationale

### 1. Code Is Already Well-Parameterized

The Terraform code is already designed with comprehensive variables. All environment differences are cleanly isolated in `terraform.tfvars`. The `.tf` files contain no hard-coded environment-specific values.

### 2. Three Environments Is Manageable

With only three environments (development, staging, production), the maintenance overhead of keeping files in sync is minimal. When structural changes are needed:

- Copy changes to all three folders
- Review in PR to ensure consistency
- Terraform plan for each workspace validates correctness

### 3. Environment Isolation Aligns with ADR-003

Per ADR-003 (Infrastructure Layering and Repository Structure), each environment has its own Terraform Cloud workspace with a distinct working directory. This physical separation:

- Enables independent state management
- Allows environment-specific approval workflows
- Limits blast radius of changes

### 4. Flexibility for Future Divergence

Production environments often require security or compliance features that don't apply to development:

- Different network access controls
- Additional monitoring or audit logging
- Stricter IAM policies
- Environment-specific integrations

Keeping separate folders makes it trivial to add environment-specific resources without module complexity.

### 5. Simpler Troubleshooting

When debugging an issue in staging, all relevant code is in one folder. No need to:

- Check which module version is deployed
- Navigate between module source and environment configuration
- Understand module input/output mappings

### 6. Module Versioning Overhead Not Justified

A shared module would require:

- Version tagging strategy
- Coordinated upgrades across environments
- Testing matrix for module changes
- Documentation of module interface

For three environments with identical code, this overhead isn't justified.

## When to Reconsider

This decision should be revisited if:

1. **Scale increases**: More than 5 environments use the same EKS pattern
2. **Sync failures occur**: Environments drift apart due to incomplete updates
3. **Reuse is needed**: Other teams or repositories need the same EKS configuration
4. **Change frequency increases**: Structural changes happen weekly rather than monthly

## Implementation Guidelines

### Keeping Environments in Sync

When making changes to the EKS Auto Mode configuration:

1. Make changes in one environment first (typically development)
2. Test and validate the change
3. Copy the modified `.tf` files to other environments
4. Update `terraform.tfvars` if new variables are added
5. Submit a single PR with changes to all environments
6. PR review should verify files are consistent across environments

### Drift Detection (Optional Enhancement)

Consider adding a CI job that compares `.tf` files across environments:

```bash
# Example: Check for unintended drift
diff terraform/env-development/platform-layer/eks-auto-mode/eks.tf \
     terraform/env-staging/platform-layer/eks-auto-mode/eks.tf
```

### Documentation

Each environment folder should maintain its own `README.md` with:

- Environment-specific configuration notes
- Any intentional deviations from other environments
- Links to related Terraform Cloud workspace

## Consequences

### Positive

- Simple, understandable structure
- Each environment is self-contained
- No module versioning complexity
- Aligns with existing workspace architecture
- Easy to debug issues in any environment
- Flexibility for environment-specific evolution

### Negative

- Must manually sync changes across environments
- Risk of unintentional drift without detection
- Slightly more total lines of code in repository

### Neutral

- Developers must understand that files should stay in sync
- PR reviews should check for consistency

## Related Decisions

- [ADR-003](./ADR-003-infra-layering-repository-structure.md): Infrastructure Layering and Repository Structure
- [ADR-009](./ADR-009-folder-structure.md): Folder Structure

## Review Date

This decision should be reviewed in 6 months (June 2026) or when:

- Number of environments using EKS Auto Mode exceeds 5
- Significant sync failures occur between environments
- Other repositories need to reuse the EKS configuration

---

## Document Information

- **Created**: December 5, 2025
- **Author**: Platform Engineering Team
- **Status**: Approved
- **Version**: 1.0
