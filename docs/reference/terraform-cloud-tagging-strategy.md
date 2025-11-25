# Terraform Cloud Tagging Strategy

## Overview

This document defines required and optional tags for Terraform Cloud workspaces, projects, and variable sets. Tags enable organization, filtering, policy enforcement, and alignment with AWS resource tagging.

## Terraform Cloud Tag Concepts

Unlike AWS tags (key-value pairs), Terraform Cloud uses simple string tags. To maintain alignment with AWS tagging, we use a naming convention: `key:value`.

### Tag Format Convention

```text
key:value

# Examples
environment:development
layer:foundation
owner:platform-team
```

## Required Tags (All Workspaces)

Every Terraform Cloud workspace MUST include these tags:

```text
environment:<environment-name>
managed-by:terraform-cloud
layer:<layer-name>
owner:<team-or-person>
```

### Tag Definitions

| Tag Pattern | Values | Description |
|-------------|--------|-------------|
| `environment:*` | management, development, staging, production, sandbox, local | Target AWS account/environment |
| `managed-by:*` | terraform-cloud | Indicates workspace is managed via TFC |
| `layer:*` | foundation, platform, applications, experiments | Infrastructure layer (see ADR-003) |
| `owner:*` | team-name, person-email | Team or individual responsible |

## Sandbox Workspace Tags

Sandbox workspaces require additional tags for tracking and cleanup alignment:

```text
environment:sandbox
managed-by:terraform-cloud
layer:experiments
owner:user-email
purpose:learning
auto-cleanup:true
max-lifetime:7days
```

### Sandbox-Specific Tag Definitions

| Tag Pattern | Values | Description |
|-------------|--------|-------------|
| `purpose:*` | testing, learning, experiment, integration-test | Why the workspace exists |
| `auto-cleanup:*` | true, false | Enable/disable automated workspace cleanup |
| `max-lifetime:*` | 7days, 30days, etc. | Maximum age before workspace archival |

### Protection Tags

Prevent accidental deletion or archival:

```text
auto-cleanup:false
protected:true
```

## Project-Level Tags

Terraform Cloud Projects can also have tags for organization:

```text
team:platform
cost-center:engineering
domain:infrastructure
```

## Environment-Specific Patterns

### Management Environment Workspaces

```text
environment:management
managed-by:terraform-cloud
layer:foundation
owner:platform-team
```

### Development/Staging/Production Workspaces

```text
environment:development
managed-by:terraform-cloud
layer:platform
owner:backend-team
```

### Sandbox Workspaces

```text
environment:sandbox
managed-by:terraform-cloud
layer:experiments
owner:user-example-com
purpose:learning
auto-cleanup:true
max-lifetime:7days
```

### Local Development Workspaces

```text
environment:local
managed-by:terraform-cloud
layer:sandbox-layer
owner:developer-name
purpose:local-testing
```

## AWS Tag Alignment

This table shows how Terraform Cloud tags align with AWS resource tags:

| AWS Tag Key | AWS Tag Value | TFC Tag | TFC Value |
|-------------|---------------|---------|-----------|
| Environment | Development | environment:development | - |
| ManagedBy | Terraform | managed-by:terraform-cloud | - |
| Layer | foundation | layer:foundation | - |
| Owner | team-name | owner:team-name | - |
| Purpose | learning | purpose:learning | - |
| AutoCleanup | true | auto-cleanup:true | - |
| MaxLifetime | 7days | max-lifetime:7days | - |

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

```text
# Environment-specific variable sets
scope:environment:development
scope:environment:sandbox

# Layer-specific variable sets
scope:layer:foundation
scope:layer:platform

# Team-specific variable sets
scope:team:platform
scope:team:application
```

## Run Triggers and Tags

Use tags to organize run trigger relationships:

```text
# Upstream dependencies
depends-on:foundation
depends-on:platform

# Downstream consumers
triggers:applications
triggers:experiments
```

## Policy Enforcement via Tags

### Sentinel Policy Examples

Tags can be used with Sentinel policies:

```text
# Require sandbox workspaces to have cleanup tags
environment:sandbox → must have auto-cleanup:* tag

# Restrict production deployments
environment:production → require-approval:true

# Enforce ownership
All workspaces → must have owner:* tag
```

### Tag-Based Policy Sets

Attach policy sets based on tags:

| Policy Set | Applied To Tags |
|------------|-----------------|
| sandbox-policies | environment:sandbox |
| production-policies | environment:production |
| foundation-policies | layer:foundation |

## Implementation in Terraform

### Creating Workspaces with Tags

```hcl
resource "tfe_workspace" "example" {
  name         = "development-foundation-iam-roles"
  organization = var.organization

  tag_names = [
    "environment:development",
    "managed-by:terraform-cloud",
    "layer:foundation",
    "owner:platform-team"
  ]
}
```

### Sandbox Workspace with All Tags

```hcl
resource "tfe_workspace" "sandbox_experiment" {
  name         = "sandbox-experiments-eks-learning"
  organization = var.organization

  tag_names = [
    "environment:sandbox",
    "managed-by:terraform-cloud",
    "layer:experiments",
    "owner:${var.owner}",
    "purpose:learning",
    "auto-cleanup:true",
    "max-lifetime:7days"
  ]
}
```

### Using Local Variables (Recommended)

```hcl
locals {
  common_tags = [
    "environment:${var.environment}",
    "managed-by:terraform-cloud",
    "layer:${var.layer}",
    "owner:${var.owner}"
  ]

  sandbox_tags = [
    "purpose:${var.purpose}",
    "auto-cleanup:true",
    "max-lifetime:${var.max_lifetime}"
  ]
}

resource "tfe_workspace" "example" {
  name         = "${var.environment}-${var.layer}-${var.component}"
  organization = var.organization

  tag_names = var.environment == "sandbox" ? concat(local.common_tags, local.sandbox_tags) : local.common_tags
}
```

### Project with Tags

```hcl
resource "tfe_project" "platform" {
  name         = "platform-infrastructure"
  organization = var.organization

  # Note: Project tags require TFC Plus edition
}
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

data "tfe_workspace_ids" "sandbox" {
  organization = var.organization
  tag_names    = ["environment:sandbox"]
}
```

## Filtering Workspaces by Tags

### Terraform Data Source

```hcl
# Find all sandbox workspaces
data "tfe_workspace_ids" "sandbox" {
  organization = var.organization
  tag_names    = ["environment:sandbox"]
}

# Find all foundation layer workspaces
data "tfe_workspace_ids" "foundation" {
  organization = var.organization
  tag_names    = ["layer:foundation"]
}

# Find sandbox experiments ready for cleanup
data "tfe_workspace_ids" "cleanup_candidates" {
  organization = var.organization
  tag_names    = [
    "environment:sandbox",
    "auto-cleanup:true"
  ]
}
```

### TFC CLI / API

```bash
# List workspaces with specific tag
terraform cloud workspace list -tag "environment:sandbox"

# Filter by multiple tags (AND logic)
terraform cloud workspace list -tag "environment:sandbox" -tag "layer:experiments"
```

## AI Assistant Instructions

When generating Terraform Cloud workspace configurations:

1. **Always include required tags**: `environment:*`, `managed-by:terraform-cloud`, `layer:*`, `owner:*`
2. **Use colon separator**: Format as `key:value` for AWS alignment
3. **For Sandbox**: Add `purpose:*`, `auto-cleanup:*`, `max-lifetime:*`
4. **Use local variables** for common tags to avoid repetition
5. **Use concat()** to combine common tags with workspace-specific tags
6. **Align with AWS tags**: Match values used in AWS resource tags
7. **Follow naming convention**: `<environment>-<layer>-<component>`

## Quick Reference

| Environment | Required Tags | Additional Tags |
|-------------|---------------|-----------------|
| Management | 4 base tags | - |
| Development | 4 base tags | - |
| Staging | 4 base tags | - |
| Production | 4 base tags | - |
| Sandbox | 4 base tags | purpose, auto-cleanup, max-lifetime |
| Local | 4 base tags | purpose |

**Base Tags**: `environment:*`, `managed-by:terraform-cloud`, `layer:*`, `owner:*`

## Tag Governance Checklist

- [ ] All workspaces have 4 required tags
- [ ] Sandbox workspaces have cleanup tags
- [ ] Tag values align with AWS tagging strategy
- [ ] Policy sets attached based on tags
- [ ] Variable sets scoped by tags where appropriate
- [ ] Naming convention follows `<environment>-<layer>-<component>`

## Related Documentation

- [AWS Tagging Strategy](./aws-tagging-strategy.md)
- [ADR-003: Infrastructure Layering](./architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
- [ADR-011: Sandbox Environment](./architecture-decision-register/ADR-011-sandbox-environment.md)
- [ADR-012: Automated Cleanup](./architecture-decision-register/ADR-012-sandbox-automated-cleanup.md)
