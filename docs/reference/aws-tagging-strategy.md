# AWS Tagging Strategy

## Overview

This document defines required and optional AWS resource tags for all Terraform-managed infrastructure. Tags enable resource organization, cost tracking, automation, and cleanup policies.

## Required Tags (All Environments)

Every AWS resource MUST include these tags:

```bash
tags = {
  Environment = "Management|Development|Staging|Production|Sandbox"
  ManagedBy   = "Terraform"
  Layer       = "foundation|platform|applications|experiments"
  Owner       = "team-name|person-email"
}
```

### Tag Definitions

- **Environment**: AWS account/environment name
- **ManagedBy**: Always `Terraform` for IaC-managed resources
- **Layer**: Infrastructure layer (see ADR-003)
- **Owner**: Team or individual responsible for the resource. Default to "Platform-Team".

## Sandbox Environment Tags

Sandbox resources require additional tags for automated cleanup (see ADR-011, ADR-012):

```bash
tags = {
  Environment  = "Sandbox"
  ManagedBy    = "Terraform"
  Layer        = "foundation|platform|applications|experiments"
  Owner        = "team-or-person-name"
  Purpose      = "testing|learning|experiment|integration-test"
  ExpiresOn    = "2025-12-31"  # ISO date YYYY-MM-DD
  AutoCleanup  = "true"
  MaxLifetime  = "7days"
}
```

### Sandbox-Specific Tag Definitions

- **Purpose**: Why the resource exists
- **ExpiresOn**: ISO date when resource should be deleted (YYYY-MM-DD)
- **AutoCleanup**: Enable/disable automated cleanup (`true|false`)
- **MaxLifetime**: Maximum age before deletion (e.g., `7days`, `30days`)

### Protection Tags

Prevent accidental deletion in Sandbox:

```bash
tags = {
  AutoCleanup = "false"  # Disable automated cleanup
  Protected   = "true"   # Additional protection flag
}
```

## Environment-Specific Patterns

### Management Environment

```bash
tags = {
  Environment = "Management"
  ManagedBy   = "Terraform"
  Layer       = "foundation"
  Owner       = "platform-team"
}
```

### Development/Staging/Production

```bash
tags = {
  Environment = "Development|Staging|Production"
  ManagedBy   = "Terraform"
  Layer       = "foundation|platform|applications"
  Owner       = "team-name"
}
```

### Sandbox Terraform-Managed

```bash
tags = {
  Environment = "Sandbox"
  ManagedBy   = "Terraform"
  Layer       = "experiments"
  Owner       = "user@example.com"
  Purpose     = "learning"
  ExpiresOn   = "2025-12-15"
  AutoCleanup = "true"
  MaxLifetime = "7days"
}
```

### Sandbox Manual/Console Resources

```bash
# Applied via AWS Console or CLI
tags = {
  Environment = "Sandbox"
  ManagedBy   = "Manual"
  Owner       = "user@example.com"
  Purpose     = "experiment"
  AutoCleanup = "true"
  MaxLifetime = "7days"
}
```

## Cleanup Automation Rules

### Tier 1: Terraform Destroy

- Targets: Resources tagged `ManagedBy=Terraform`
- Method: Scheduled `terraform destroy` workflow
- Trigger: `ExpiresOn` date reached
- Runs: Daily at 1 AM UTC

### Tier 2: AWS Nuke

- Targets: Resources NOT tagged `ManagedBy=Terraform`
- Method: AWS Nuke v3 (ekristen/aws-nuke)
- Exclusions: `ManagedBy=Terraform`, `Protected=true`, `AutoCleanup=false`
- Trigger: Resource age > `MaxLifetime` value
- Runs: Daily at 2 AM UTC

## Implementation Examples

### Basic Terraform Resource

```bash
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Layer       = "applications"
    Owner       = "backend-team"
    Name        = "dev-app-server-01"
  }
}
```

### Using Local Variables (Recommended)

```bash
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Layer       = var.layer
    Owner       = var.owner
  }
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  tags = merge(local.common_tags, {
    Name = "dev-app-server-01"
  })
}
```

### Sandbox Experiment

```bash
locals {
  common_tags = {
    Environment = "Sandbox"
    ManagedBy   = "Terraform"
    Layer       = "experiments"
    Owner       = var.owner
    Purpose     = var.purpose
    ExpiresOn   = var.expires_on
    AutoCleanup = "true"
    MaxLifetime = var.max_lifetime
  }
}

resource "aws_instance" "experiment" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  tags = merge(local.common_tags, {
    Name        = "sandbox-${var.owner}-experiment"
    Experiment  = "eks-learning"
  })
}
```

### With Validation

```bash
variable "expires_on" {
  description = "Date when resources should be deleted (YYYY-MM-DD)"
  type        = string

  validation {
    condition     = can(formatdate("2006-01-02", var.expires_on))
    error_message = "ExpiresOn must be valid ISO date (YYYY-MM-DD)."
  }
}

variable "max_lifetime" {
  description = "Maximum resource lifetime"
  type        = string
  default     = "7days"

  validation {
    condition     = can(regex("^[0-9]+(days|hours)$", var.max_lifetime))
    error_message = "MaxLifetime must be format: 7days, 24hours, etc."
  }
}
```

## AI Assistant Instructions

When generating Terraform code:

1. **Always include required tags**: `Environment`, `ManagedBy`, `Layer`, `Owner`
2. **Use local variables** for common tags to avoid repetition
3. **For Sandbox**: Add `Purpose`, `ExpiresOn`, `AutoCleanup`, `MaxLifetime`
4. **Use merge()** to combine common tags with resource-specific tags
5. **Validate dates**: Use validation blocks for `ExpiresOn` format
6. **Check environment**: Adjust tags based on target environment

## Quick Reference

| Environment | Required Tags | Additional Tags |
|-------------|---------------|-----------------|
| Management | 4 base tags | - |
| Development | 4 base tags | - |
| Staging | 4 base tags | - |
| Production | 4 base tags | - |
| Sandbox | 4 base tags | Purpose, ExpiresOn, AutoCleanup, MaxLifetime |

**Base Tags**: Environment, ManagedBy, Layer, Owner

## Related Documentation

- [ADR-003: Infrastructure Layering](./architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
- [ADR-011: Sandbox Environment](./architecture-decision-register/ADR-011-sandbox-environment.md)
- [ADR-012: Automated Cleanup](./architecture-decision-register/ADR-012-sandbox-automated-cleanup.md)
