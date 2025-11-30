# Terraform Cloud Tagging Strategy

## Overview

This document defines required and optional tags for Terraform Cloud workspaces, projects, and variable sets. Tags enable organization, filtering, policy enforcement, and alignment with AWS resource tagging.

## Terraform Cloud Tag Concepts

As of **tfe provider v0.65.0+** (released 2025), Terraform Cloud supports proper **key-value pair tags** (called "tag bindings"), in addition to the legacy flat string tags.

### Tag Systems Comparison

| Feature | Legacy Tags (`tag_names`) | Key-Value Tags (`tags`) |
|---------|---------------------------|-------------------------|
| Format | Single string: `"environment:development"` | Map: `{ environment = "development" }` |
| Provider attribute | `tag_names` (list of strings) | `tags` (map of strings) |
| Inheritance | None | Projects → Workspaces |
| API endpoint | `/relationships/tags` | `/tag-bindings` |
| Recommended | No (legacy) | **Yes** |

### Key-Value Tags Format (Recommended)

```hcl
tags = {
  environment = "development"
  layer       = "foundation"
  owner       = "platform-team"
}
```

### Constraints

- Maximum **10 direct tags** per workspace + **10 inherited tags** from project
- Key: max 128 characters
- Value: max 256 characters
- **Reserved prefixes**: Cannot use `hc:` or `hcp:` key prefixes

### Tag Inheritance

Tags can be set at the **project level** and automatically inherited by all workspaces in that project. Use `effective_tags` (read-only) to see the combined direct + inherited tags.

```hcl
resource "tfe_workspace" "example" {
  name       = "my-workspace"
  project_id = tfe_project.platform.id

  tags = {
    layer = "platform"  # Direct tag
  }

  # effective_tags will include both direct tags AND tags from the project
}
```

### Legacy Format (Deprecated)

The legacy `tag_names` attribute uses colon-separated strings. This is still supported but **not recommended** for new workspaces:

```hcl
# DEPRECATED - use tags map instead
tag_names = [
  "environment:development",
  "layer:foundation"
]
```

## Required Tags (All Workspaces)

Every Terraform Cloud workspace MUST include these tags:

```hcl
tags = {
  environment = "<environment-name>"
  managed-by  = "terraform-cloud"
  layer       = "<layer-name>"
  owner       = "<team-or-person>"
}
```

### Tag Definitions

| Tag Key | Values | Description |
|---------|--------|-------------|
| `environment` | management, development, staging, production, sandbox, local | Target AWS account/environment |
| `managed-by` | terraform-cloud | Indicates workspace is managed via TFC |
| `layer` | foundation, platform, applications, experiments | Infrastructure layer (see ADR-003) |
| `owner` | team-name, person-email | Team or individual responsible |

## Sandbox Workspace Tags

Sandbox workspaces require additional tags for tracking and cleanup alignment:

```hcl
tags = {
  environment  = "sandbox"
  managed-by   = "terraform-cloud"
  layer        = "experiments"
  owner        = "user-email"
  purpose      = "learning"
  auto-cleanup = "true"
  max-lifetime = "7days"
}
```

### Sandbox-Specific Tag Definitions

| Tag Key | Values | Description |
|---------|--------|-------------|
| `purpose` | testing, learning, experiment, integration-test | Why the workspace exists |
| `auto-cleanup` | true, false | Enable/disable automated workspace cleanup |
| `max-lifetime` | 7days, 30days, etc. | Maximum age before workspace archival |

### Protection Tags

Prevent accidental deletion or archival:

```hcl
tags = {
  auto-cleanup = "false"
  protected    = "true"
}
```

## Project-Level Tags

Terraform Cloud Projects support tags that are **inherited by all workspaces** in the project. This is ideal for organization-wide or environment-wide tags:

```hcl
resource "tfe_project" "development" {
  name         = "aws-development"
  organization = var.organization

  # Tags set on projects are inherited by workspaces
  # Note: Project tags via tfe_project_tag_binding resource
}

# Workspaces in this project automatically inherit project tags
# Use effective_tags to see combined direct + inherited tags
```

### Recommended Project Tags

| Tag Key | Description |
|---------|-------------|
| `team` | Owning team name |
| `cost-center` | Cost allocation center |
| `domain` | Business domain |
| `environment` | Environment name (inherited by all workspaces) |

## Environment-Specific Patterns

### Management Environment Workspaces

```hcl
tags = {
  environment = "management"
  managed-by  = "terraform-cloud"
  layer       = "foundation"
  owner       = "platform-team"
}
```

### Development/Staging/Production Workspaces

```hcl
tags = {
  environment = "development"
  managed-by  = "terraform-cloud"
  layer       = "platform"
  owner       = "backend-team"
}
```

### Sandbox Workspaces

```hcl
tags = {
  environment  = "sandbox"
  managed-by   = "terraform-cloud"
  layer        = "experiments"
  owner        = "user-example-com"
  purpose      = "learning"
  auto-cleanup = "true"
  max-lifetime = "7days"
}
```

### Local Development Workspaces

```hcl
tags = {
  environment = "local"
  managed-by  = "terraform-cloud"
  layer       = "sandbox-layer"
  owner       = "developer-name"
  purpose     = "local-testing"
}
```

## AWS Tag Alignment

With proper key-value tags, Terraform Cloud tags now directly align with AWS resource tags:

| AWS Tag Key | AWS Tag Value | TFC Tag Key | TFC Tag Value |
|-------------|---------------|-------------|---------------|
| Environment | Development | environment | development |
| ManagedBy | Terraform | managed-by | terraform-cloud |
| Layer | foundation | layer | foundation |
| Owner | team-name | owner | team-name |
| Purpose | learning | purpose | learning |
| AutoCleanup | true | auto-cleanup | true |
| MaxLifetime | 7days | max-lifetime | 7days |

## Workspace Naming Convention

Combine tags with naming for easy identification:

```text
# Pattern
<environment>-<layer>-<component>

# Examples
development-foundation-iam-roles
sandbox-experiments-eks-learning
management-platform-github-runners
local-sandbox-localstack-testing
```

## Variable Set Tags

Tag variable sets to control which workspaces they apply to:

```hcl
# Scope by tag key-value pairs
tags = {
  scope-environment = "development"
  scope-layer       = "foundation"
  scope-team        = "platform"
}
```

## Run Triggers and Tags

Use tags to organize run trigger relationships:

```hcl
tags = {
  depends-on = "foundation"   # Upstream dependencies
  triggers   = "applications" # Downstream consumers
}
```

## Policy Enforcement via Tags

### Sentinel Policy Examples

Tags can be used with Sentinel policies:

```text
# Require sandbox workspaces to have cleanup tags
environment = "sandbox" → must have auto-cleanup tag

# Restrict production deployments
environment = "production" → require-approval = "true"

# Enforce ownership
All workspaces → must have owner tag
```

### Tag-Based Policy Sets

Attach policy sets based on tags:

| Policy Set | Applied To Tags |
|------------|-----------------|
| sandbox-policies | `environment = "sandbox"` |
| production-policies | `environment = "production"` |
| foundation-policies | `layer = "foundation"` |

## Implementation in Terraform

### Creating Workspaces with Tags (Recommended)

```hcl
resource "tfe_workspace" "example" {
  name         = "development-foundation-iam-roles"
  organization = var.organization
  project_id   = tfe_project.development.id

  tags = {
    environment = "development"
    managed-by  = "terraform-cloud"
    layer       = "foundation"
    owner       = "platform-team"
  }

  # Read-only: shows direct tags + inherited from project
  # effective_tags = { ... }
}
```

### Sandbox Workspace with All Tags

```hcl
resource "tfe_workspace" "sandbox_experiment" {
  name         = "sandbox-experiments-eks-learning"
  organization = var.organization
  project_id   = tfe_project.sandbox.id

  tags = {
    environment  = "sandbox"
    managed-by   = "terraform-cloud"
    layer        = "experiments"
    owner        = var.owner
    purpose      = "learning"
    auto-cleanup = "true"
    max-lifetime = "7days"
  }
}
```

### Using Local Variables (Recommended)

```hcl
locals {
  common_tags = {
    environment = var.environment
    managed-by  = "terraform-cloud"
    layer       = var.layer
    owner       = var.owner
  }

  sandbox_tags = {
    purpose      = var.purpose
    auto-cleanup = "true"
    max-lifetime = var.max_lifetime
  }
}

resource "tfe_workspace" "example" {
  name         = "${var.environment}-${var.layer}-${var.component}"
  organization = var.organization
  project_id   = var.project_id

  tags = var.environment == "sandbox" ? merge(local.common_tags, local.sandbox_tags) : local.common_tags
}
```

### Ignoring Additional Tags

If tags are managed externally (e.g., via UI or API), use `ignore_additional_tags` to prevent Terraform from removing them:

```hcl
resource "tfe_workspace" "example" {
  name         = "my-workspace"
  organization = var.organization

  tags = {
    environment = "development"
    managed-by  = "terraform-cloud"
  }

  # Don't remove tags added outside of Terraform
  ignore_additional_tags = true
}
```

### Project with Tag Inheritance

```hcl
resource "tfe_project" "development" {
  name         = "aws-development"
  organization = var.organization
}

# Tags on projects are inherited by workspaces
# Use tfe_project_tag_binding for project-level tags (if available in your provider version)
```

### Variable Set with Workspace Tags Filter

```hcl
resource "tfe_variable_set" "sandbox_vars" {
  name         = "sandbox-environment-variables"
  organization = var.organization
}

resource "tfe_workspace_variable_set" "sandbox" {
  for_each = toset([
    for ws in data.tfe_workspace_ids.sandbox.ids : ws
  ])

  variable_set_id = tfe_variable_set.sandbox_vars.id
  workspace_id    = each.value
}

# Filter workspaces by tag key-value pairs
data "tfe_workspace_ids" "sandbox" {
  organization = var.organization

  tag_filters {
    key   = "environment"
    value = "sandbox"
  }
}
```

## Filtering Workspaces by Tags

### Terraform Data Source

```hcl
# Find all sandbox workspaces using tag_filters
data "tfe_workspace_ids" "sandbox" {
  organization = var.organization

  tag_filters {
    key   = "environment"
    value = "sandbox"
  }
}

# Find all foundation layer workspaces
data "tfe_workspace_ids" "foundation" {
  organization = var.organization

  tag_filters {
    key   = "layer"
    value = "foundation"
  }
}

# Find sandbox experiments ready for cleanup (multiple filters = AND logic)
data "tfe_workspace_ids" "cleanup_candidates" {
  organization = var.organization

  tag_filters {
    key   = "environment"
    value = "sandbox"
  }

  tag_filters {
    key   = "auto-cleanup"
    value = "true"
  }
}

# Legacy format still works but not recommended
data "tfe_workspace_ids" "legacy_example" {
  organization = var.organization
  tag_names    = ["environment:sandbox"]  # Deprecated
}
```

### TFC CLI / API

```bash
# List workspaces with specific tag (key-value)
terraform cloud workspace list --filter="tags.environment=sandbox"

# Filter by multiple tags (AND logic)
terraform cloud workspace list --filter="tags.environment=sandbox" --filter="tags.layer=experiments"
```

### API: Tag Bindings

```bash
# Get workspace tag bindings (key-value)
curl -H "Authorization: Bearer $TFC_TOKEN" \
  "https://app.terraform.io/api/v2/workspaces/{workspace_id}/tag-bindings"

# Get effective tags (direct + inherited from project)
curl -H "Authorization: Bearer $TFC_TOKEN" \
  "https://app.terraform.io/api/v2/workspaces/{workspace_id}/effective-tag-bindings"
```

## AI Assistant Instructions

When generating Terraform Cloud workspace configurations:

1. **Use `tags` attribute (map)**: Prefer `tags = { key = "value" }` over legacy `tag_names`
2. **Always include required tags**: `environment`, `managed-by`, `layer`, `owner`
3. **For Sandbox**: Add `purpose`, `auto-cleanup`, `max-lifetime`
4. **Use local variables** with `merge()` to combine common and workspace-specific tags
5. **Set project-level tags** for inheritance where applicable
6. **Use `ignore_additional_tags`** if tags are also managed outside Terraform
7. **Align with AWS tags**: Key names and values should match AWS resource tags
8. **Follow naming convention**: `<environment>-<layer>-<component>`
9. **Use `tag_filters`** in data sources for workspace lookups
10. **Avoid reserved prefixes**: Do not use `hc:` or `hcp:` as key prefixes

## Migration from Legacy Tags

If migrating from `tag_names` to `tags`:

```hcl
# Before (legacy)
resource "tfe_workspace" "example" {
  name      = "my-workspace"
  tag_names = ["environment:development", "layer:foundation"]
}

# After (recommended)
resource "tfe_workspace" "example" {
  name = "my-workspace"
  tags = {
    environment = "development"
    layer       = "foundation"
  }
}
```

**Note**: The two tag systems are independent. Switching from `tag_names` to `tags` will not automatically migrate existing tags.

## Quick Reference

| Environment | Required Tags | Additional Tags |
|-------------|---------------|-----------------|
| Management | 4 base tags | - |
| Development | 4 base tags | - |
| Staging | 4 base tags | - |
| Production | 4 base tags | - |
| Sandbox | 4 base tags | purpose, auto-cleanup, max-lifetime |
| Local | 4 base tags | purpose |

**Base Tags**: `environment`, `managed-by`, `layer`, `owner`

### Provider Version Requirements

| Feature | Minimum tfe Provider Version |
|---------|------------------------------|
| `tags` (map attribute) | v0.65.0 |
| `effective_tags` (inherited) | v0.65.0 |
| `ignore_additional_tags` | v0.65.0 |
| `tag_filters` in data sources | v0.65.0 |

## Tag Governance Checklist

- [ ] All workspaces have 4 required tags (using `tags` map)
- [ ] Sandbox workspaces have cleanup tags
- [ ] Tag values align with AWS tagging strategy
- [ ] Policy sets attached based on tags
- [ ] Variable sets scoped by tags where appropriate
- [ ] Naming convention follows `<environment>-<layer>-<component>`
- [ ] Using tfe provider v0.65.0 or later
- [ ] Project-level tags configured for inheritance
- [ ] Legacy `tag_names` migrated to `tags` map

## Related Documentation

- [AWS Tagging Strategy](./aws-tagging-strategy.md)
- [ADR-003: Infrastructure Layering](./architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
- [ADR-011: Sandbox Environment](./architecture-decision-register/ADR-011-sandbox-environment.md)
- [ADR-012: Automated Cleanup](./architecture-decision-register/ADR-012-sandbox-automated-cleanup.md)
- [HCP Terraform Workspace Tags Documentation](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/tags)
- [tfe Provider Changelog](https://github.com/hashicorp/terraform-provider-tfe/blob/main/CHANGELOG.md)
