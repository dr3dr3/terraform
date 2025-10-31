# Terraform Best Practices Guide

> Tactical patterns and conventions for implementing Infrastructure as Code with Terraform.

**Last Updated**: October 27, 2025

---

## Project Structure

### Standard Directory Layout
```
terraform/
├── modules/                    # Reusable modules
│   ├── vpc/
│   ├── eks-cluster/
│   └── rds-postgres/
├── environments/              # Environment-specific configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── production/
├── global/                    # Shared/global resources
│   └── iam/
└── docs/
    └── architecture/
        ├── ADR-INDEX.md
        └── ARCHITECTURE-PRINCIPLES.md
```

### File Organization Per Environment
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variable declarations
- `outputs.tf` - Output value declarations
- `terraform.tfvars` - Variable values (non-sensitive)
- `backend.tf` - Backend configuration
- `versions.tf` - Terraform and provider version constraints
- `locals.tf` - Local values and computed variables
- `data.tf` - Data source definitions

---

## GitOps Workflow

### Branching Strategy
```
main (production)
├── staging (auto-deploy)
└── feature/* (PR → staging)
```

### Pull Request Process
1. Create feature branch from `staging`
2. Make infrastructure changes
3. CI runs: `terraform fmt -check`, `terraform validate`, `tflint`, `checkov`
4. CI runs: `terraform plan` and posts result as PR comment
5. Peer review required (at least 1 approval)
6. Merge to `staging` → auto-apply to staging environment
7. After validation, PR from `staging` to `main`
8. Manual approval required for production apply

### CI/CD Pipeline Stages
```yaml
# Example pipeline
stages:
  - validate   # fmt, validate, lint
  - security   # tfsec, checkov, Sentinel
  - plan       # terraform plan
  - approve    # manual gate (production only)
  - apply      # terraform apply
  - notify     # Slack/email notification
```

---

## Code Standards

### Naming Conventions

**Resources**
```hcl
# Pattern: {environment}-{service}-{resource_type}
resource "aws_s3_bucket" "prod_app_logs" {
  bucket = "prod-app-logs-${data.aws_caller_identity.current.account_id}"
}
```

**Variables**
```hcl
# Use snake_case
variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

# Group related variables with prefixes
variable "database_instance_class" {}
variable "database_allocated_storage" {}
variable "database_backup_retention_period" {}
```

**Modules**
```hcl
# Use descriptive names
module "primary_vpc" {
  source = "../../modules/vpc"
}

module "application_database" {
  source = "../../modules/rds-postgres"
}
```

### Tagging Standard
```hcl
locals {
  common_tags = {
    Environment  = var.environment
    ManagedBy    = "Terraform"
    Project      = var.project_name
    Owner        = var.team_email
    CostCenter   = var.cost_center
    Compliance   = var.compliance_level
  }
}

resource "aws_instance" "app" {
  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-app-server"
      Role = "application"
    }
  )
}
```

---

## State Management

### Backend Configuration
```hcl
# backend.tf - separate file for easy environment switching
terraform {
  backend "remote" {
    organization = "your-org"
    
    workspaces {
      name = "app-production"
    }
  }
}
```

### State Organization Strategies

**Option 1: Monolithic State** (Simple projects)
- Single state file per environment
- All resources in one Terraform root module

**Option 2: Layered State** (Recommended)
```
environments/production/
├── 01-networking/     # VPC, subnets (rarely changes)
├── 02-data/          # Databases, caches (changes occasionally)
├── 03-compute/       # EKS, instances (changes frequently)
└── 04-applications/  # App-specific resources (changes very frequently)
```

**Option 3: Service-Oriented State**
- Separate state per microservice
- Shared infrastructure in common state
- Use `terraform_remote_state` data sources for cross-references

---

## Module Design

### Module Best Practices

**Good Module**
```hcl
# modules/vpc/main.tf
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}
```

### Module Versioning
```hcl
# Use specific version tags
module "vpc" {
  source = "git::https://github.com/your-org/terraform-modules.git//vpc?ref=v1.2.3"
  # NOT: ?ref=main (unpredictable)
  # NOT: ?ref=latest (not a real tag)
}

# Or use Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"  # Pin exact version
}
```

---

## Security Practices

### Secrets Management
```hcl
# ❌ NEVER do this
variable "database_password" {
  default = "MyP@ssw0rd123"
}

# ✅ Use secret management
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# ✅ Or use Terraform Cloud variables marked as sensitive
# Set TF_VAR_database_password as sensitive variable
variable "database_password" {
  type      = string
  sensitive = true
}
```

### Sensitive Output Handling
```hcl
output "database_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "database_password" {
  description = "Database password"
  value       = aws_db_instance.main.password
  sensitive   = true  # Won't be displayed in logs
}
```

---

## Testing & Validation

### Pre-Commit Checks
```bash
# .pre-commit-config.yaml or Makefile
terraform fmt -recursive
terraform validate
tflint
checkov -d .
terraform-docs markdown . > README.md
```

### Policy as Code (Sentinel Example)
```hcl
# policies/require-tags.sentinel
import "tfplan/v2" as tfplan

mandatory_tags = ["Environment", "Owner", "ManagedBy"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.change.after.tags contains mandatory_tags
  }
}
```

### Cost Estimation
```bash
# In CI/CD pipeline
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
infracost breakdown --path tfplan.json
```

---

## Common Patterns

### Dynamic Resource Creation
```hcl
# Create resources based on map
variable "environments" {
  type = map(object({
    instance_type = string
    instance_count = number
  }))
  default = {
    dev = {
      instance_type  = "t3.micro"
      instance_count = 1
    }
    prod = {
      instance_type  = "t3.large"
      instance_count = 3
    }
  }
}

resource "aws_instance" "app" {
  count         = var.environments[var.environment].instance_count
  instance_type = var.environments[var.environment].instance_type
}
```

### Conditional Resources
```hcl
# Create resource only in production
resource "aws_cloudwatch_alarm" "high_cpu" {
  count = var.environment == "production" ? 1 : 0
  # ... alarm configuration
}
```

### Cross-Stack References
```hcl
# Reference outputs from another state
data "terraform_remote_state" "networking" {
  backend = "remote"
  
  config = {
    organization = "your-org"
    workspaces = {
      name = "networking-${var.environment}"
    }
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]
  vpc_security_group_ids = [data.terraform_remote_state.networking.outputs.app_security_group_id]
}
```

---

## Disaster Recovery

### State Backup
- Terraform Cloud: Automatic state versioning
- S3 Backend: Enable versioning on bucket
- Regular state exports: `terraform state pull > backup.tfstate`

### Recovery Procedures
```bash
# Restore from backup
terraform state push backup.tfstate

# Remove corrupted resource from state
terraform state rm aws_instance.corrupted

# Import existing resource
terraform import aws_instance.existing i-1234567890abcdef0

# Force resource recreation
terraform taint aws_instance.app
terraform apply
```

---

## Migration Strategies

### From Manual to Terraform
1. **Inventory**: Document all existing resources
2. **Import**: `terraform import` existing resources
3. **Validate**: `terraform plan` shows no changes
4. **Iterate**: Gradually bring more resources under management
5. **Decommission**: Remove manual change access

### Between Backends
```bash
# 1. Backup current state
terraform state pull > backup.tfstate

# 2. Update backend configuration
# 3. Migrate state
terraform init -migrate-state

# 4. Verify
terraform plan  # Should show no changes
```

---

## Troubleshooting

### Common Issues

**State Lock Errors**
```bash
# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

**Plan Shows Unexpected Changes**
```bash
# Show detailed diff
terraform plan -out=tfplan
terraform show tfplan

# Show state for specific resource
terraform state show aws_instance.app
```

**Drift Detection**
```bash
# Refresh state and show drift
terraform plan -refresh-only
```

---

**Related**: 
- [Architecture Principles](ARCHITECTURE-PRINCIPLES.md)
- [ADR Index](ADR-INDEX.md)