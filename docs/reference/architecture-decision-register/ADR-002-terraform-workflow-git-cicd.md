# Architecture Decision Record: Terraform Workflow - Git Branching, CI/CD, and Terraform Cloud Setup

## Status
Proposed

## Context

We need to establish how our Infrastructure as Code (IaC) will flow from development through to production. This involves three interconnected decisions:

1. **Git Branching Strategy**: How we organize branches in our repository
2. **CI/CD Pipeline**: How code changes trigger infrastructure deployments
3. **Terraform Cloud Workflow**: Whether to use VCS-driven, CLI-driven, or API-driven workflow

### Current Situation
- Using Terraform Cloud for state management (per ADR-001)
- Separate AWS accounts for Dev, Staging, and Production environments
- Team of ~5 engineers working on infrastructure
- Need for collaborative review process
- Requirement for progressive deployment (dev → staging → prod)

### Key Requirements
- Clear promotion path from dev to production
- Peer review for all infrastructure changes
- Automated validation and testing
- Manual approval gates for production
- Audit trail of all changes
- Prevention of drift and unauthorized changes
- Support for both planned changes and emergency fixes

## Decision Drivers

- **Team Size**: Small team (~5 engineers) needs simple, maintainable workflows
- **Risk Management**: Production changes must be thoroughly reviewed and tested
- **Automation**: Reduce manual steps and human error
- **Collaboration**: Enable multiple engineers to work simultaneously
- **Compliance**: Full audit trail and approval process
- **Simplicity**: Avoid unnecessary complexity that slows down the team
- **GitOps Principles**: Git as single source of truth

## Options Considered

### Option 1: VCS-Driven Workflow with Environment Branches

#### Overview
Use Terraform Cloud's VCS-driven workflow with separate Git branches per environment.

#### Configuration
```
Git Branches:
├── main (production)
├── staging
└── dev

Terraform Cloud:
├── Workspace: app-production (linked to main branch)
├── Workspace: app-staging (linked to staging branch)
└── Workspace: app-dev (linked to dev branch)

Directory Structure:
terraform/
├── modules/          # Reusable modules
├── main.tf           # Resource definitions
├── variables.tf      # Variable declarations
├── dev.tfvars        # Dev-specific values
├── staging.tfvars    # Staging-specific values
└── prod.tfvars       # Prod-specific values
```

#### Workflow
1. Developer creates feature branch from `dev`
2. Opens PR to `dev` branch
3. Terraform Cloud automatically runs speculative plan on PR
4. Team reviews PR and plan results
5. Merge to `dev` → Terraform Cloud auto-applies to dev environment
6. After validation, create PR from `dev` to `staging`
7. Merge to `staging` → Terraform Cloud auto-applies to staging
8. After validation, create PR from `staging` to `main`
9. Manual approval required in Terraform Cloud
10. Merge to `main` → Terraform Cloud applies to production

#### Pros
- **Maximum automation**: Terraform Cloud handles all planning and applying
- **GitOps native**: Perfect alignment with GitOps principles
- **Simple setup**: Minimal configuration required
- **Built-in speculative plans**: Automatic plan on every PR
- **Clear audit trail**: All changes visible in Git + Terraform Cloud
- **No CI/CD tooling required**: Terraform Cloud handles everything
- **Webhook-driven**: Automatic triggering on commits
- **Cost control**: Plan/apply happens in Terraform Cloud (no CI runners needed)

#### Cons
- **Branch duplication**: Same code exists on multiple branches
- **Merge conflicts**: Cherry-picking or merging between branches can be complex
- **Limited pre-apply validation**: Can't easily run custom scripts before Terraform
- **Less flexible**: Locked into Terraform Cloud's workflow
- **All-or-nothing**: Can't selectively apply parts of configuration
- **Emergency fixes**: Hotfixes to prod must be backported to lower environments

#### Best For
- Teams new to Terraform and IaC
- Organizations wanting maximum automation
- Teams without existing CI/CD infrastructure
- Straightforward infrastructure without complex validation needs

---

### Option 2: VCS-Driven Workflow with Mono-Branch + Directories

#### Overview
Single main branch with environment-specific directories, each linked to separate Terraform Cloud workspace.

#### Configuration
```
Git Branches:
└── main

Terraform Cloud:
├── Workspace: app-production (linked to main, working-dir: environments/production)
├── Workspace: app-staging (linked to main, working-dir: environments/staging)
└── Workspace: app-dev (linked to main, working-dir: environments/dev)

Directory Structure:
terraform/
├── modules/              # Reusable modules
│   ├── vpc/
│   ├── eks/
│   └── rds/
├── environments/
│   ├── dev/
│   │   ├── main.tf       # Calls modules
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
```

#### Workflow
1. Developer creates feature branch from `main`
2. Makes changes to relevant environment directory
3. Opens PR to `main`
4. Terraform Cloud runs speculative plans for affected workspaces
5. Team reviews PR and plan results
6. Merge to `main` → Terraform Cloud auto-applies to affected environments
7. Use Terraform Cloud's auto-apply settings per workspace:
   - Dev: Auto-apply enabled
   - Staging: Auto-apply enabled with notifications
   - Production: Manual apply required (approval gate)

#### Pros
- **No branch duplication**: Single source of truth on main branch
- **No merge conflicts between environments**: Each environment is separate directory
- **Clear separation**: Easy to see what differs between environments
- **Module reuse**: Environments compose shared modules
- **Standard Git workflow**: Familiar to most developers
- **Easier to maintain**: Changes to modules propagate naturally
- **Selective deployment**: Can choose which environments to update

#### Cons
- **Less isolation**: All environments change together on main branch
- **Requires discipline**: Must manually control which directories are modified
- **Risk of accidental changes**: Could modify prod when intending to change dev
- **Less clear promotion**: No explicit "promote to staging" action
- **Workspace configuration complexity**: Must configure working directory per workspace

#### Best For
- Teams experienced with Terraform
- Organizations with mature module libraries
- Projects where environments should stay in sync
- Teams wanting to avoid branch management overhead

---

### Option 3: CLI-Driven Workflow with External CI/CD

#### Overview
Use Terraform Cloud for state/collaboration, but trigger runs via CI/CD pipeline (GitHub Actions, GitLab CI, etc.).

#### Configuration
```
Git Branches:
└── main (with environment directories)

Terraform Cloud:
├── Workspace: app-production (CLI-driven, no VCS link)
├── Workspace: app-staging (CLI-driven, no VCS link)
└── Workspace: app-dev (CLI-driven, no VCS link)

CI/CD Pipeline Stages:
1. Validate (terraform fmt, validate, tflint, tfsec)
2. Plan (runs terraform plan via CLI)
3. Security Scan (checkov, Sentinel)
4. Manual Approval (production only)
5. Apply (terraform apply via CLI)
6. Notify (Slack, email)
```

#### Workflow
1. Developer creates feature branch from `main`
2. Opens PR to `main`
3. CI/CD pipeline runs:
   - Validation checks (fmt, validate, lint)
   - Security scanning (tfsec, checkov)
   - Terraform plan (via Terraform CLI to TF Cloud)
   - Posts plan as PR comment
4. Team reviews PR and plan
5. Merge to `main` → CI/CD pipeline runs for all environments
6. Dev: Automatically applies
7. Staging: Automatically applies after dev succeeds
8. Production: Requires manual approval in CI/CD, then applies

#### Pros
- **Maximum flexibility**: Full control over pre/post deployment actions
- **Custom validation**: Run any validation tools in pipeline
- **Integration options**: Integrate with existing CI/CD tools
- **Complex workflows**: Support for notifications, approvals, rollbacks
- **Cost optimization**: Can run custom checks before expensive Terraform operations
- **Multi-tool support**: Can use Terragrunt, Atlantis, or other tools
- **Familiar CI/CD patterns**: Developers already know GitHub Actions/GitLab CI

#### Cons
- **More complexity**: Must maintain CI/CD pipeline configuration
- **Additional cost**: Requires CI/CD runners
- **More moving parts**: More things that can break
- **Slower feedback**: CI/CD queue times vs instant Terraform Cloud webhooks
- **Duplicate logic**: Some validation duplicated between CI/CD and Terraform Cloud
- **Requires expertise**: Need to understand both Terraform and CI/CD tool
- **Credential management**: Must securely manage Terraform Cloud API tokens in CI/CD

#### Best For
- Teams with existing CI/CD investment
- Organizations needing complex pre-deployment validation
- Advanced teams comfortable with CI/CD and Terraform
- Projects requiring integration with multiple tools

---

### Option 4: Hybrid - VCS-Driven + CLI for Special Cases

#### Overview
Primary workflow uses VCS-driven for normal changes, but CLI-driven available for emergency fixes or advanced scenarios.

#### Configuration
- Most workspaces: VCS-driven (primary workflow)
- Special workspace: CLI-driven (for emergencies, testing, or advanced use cases)

#### Pros
- Best of both worlds: Simplicity of VCS + flexibility when needed
- Gradual adoption: Can start with VCS and add CLI later
- Emergency path: CLI option for hotfixes bypassing full workflow

#### Cons
- Two different workflows to maintain
- Team confusion about which to use when
- Added complexity without clear benefit for small teams

---

## Comparison Matrix

| Criterion | Environment Branches | Mono-Branch + Directories | CLI-Driven + CI/CD | Hybrid |
|-----------|---------------------|---------------------------|-------------------|--------|
| **Setup Complexity** | Low | Medium | High | High |
| **Operational Complexity** | Medium (branch mgmt) | Low | High (CI/CD mgmt) | High |
| **GitOps Alignment** | Excellent | Good | Fair | Good |
| **Merge Conflict Risk** | High | Low | Low | Medium |
| **Promotion Clarity** | Excellent | Fair | Good | Fair |
| **Custom Validation** | Limited | Limited | Excellent | Good |
| **Team Learning Curve** | Low | Low | Medium-High | High |
| **Cost (infra)** | Low | Low | Medium (CI runners) | Medium |
| **Emergency Fix Process** | Complex (backport) | Simple | Simple | Medium |
| **Selective Apply** | No | Yes | Yes | Yes |
| **Best for Team Size** | 3-10 | 5-20 | 10+ | 10+ |

## Decision

**Recommended: Option 2 - VCS-Driven Workflow with Mono-Branch + Directories**

## Rationale

Given your team size (~5 engineers), separate AWS accounts per environment, and the need for both simplicity and progressive deployment, the mono-branch with directories approach is optimal for the following reasons:

### 1. Avoids Branch Management Complexity
Branch-based strategies lead to inevitable merge conflicts when multiple engineers work on feature branches, as changes to common modules must be carefully synchronized across environment branches. With directories, you maintain a single source of truth on the main branch.

### 2. Leverages Terraform Cloud's Native Strengths
VCS integrations trigger Terraform runs automatically and teams no longer need to manually run terraform plan or apply, reducing human error and ensuring consistency across environments. This maximizes automation while keeping setup simple.

### 3. Module Reuse and Maintainability
Directory structure encourages proper module design where common infrastructure patterns are abstracted into reusable modules. Changes to modules automatically affect all environments that use them, keeping infrastructure consistent.

### 4. Clear Separation of Concerns
Each environment directory contains its own `terraform.tfvars` making environment-specific configurations explicit and easy to review. This reduces risk of accidental cross-environment changes.

### 5. Aligns with Existing Decision
This approach works seamlessly with Terraform Cloud (ADR-001), using its native VCS-driven workflow without requiring additional CI/CD tooling investment.

### 6. Progressive Deployment Through Terraform Cloud Settings
```
Dev Workspace: 
- Auto-apply: Enabled
- Notifications: Basic

Staging Workspace:
- Auto-apply: Enabled  
- Notifications: Enhanced (Slack)

Production Workspace:
- Auto-apply: Disabled (manual approval required)
- Notifications: All (Slack + Email)
- Sentinel policies: Enforced
```

### 7. Scalability
As your team grows and infrastructure becomes more complex, this approach scales well. You can:
- Add new environments by creating new directories
- Extract common patterns into modules
- Implement Sentinel policies for governance
- Add more granular workspace organization using Terraform Cloud Projects

## Implementation Plan

### Phase 1: Repository Setup (Week 1)

**Step 1: Create Directory Structure**
```bash
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── eks/
│   └── rds/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── README.md
│   ├── staging/
│   └── production/
└── docs/
    └── architecture/
        ├── ADR-INDEX.md
        ├── ARCHITECTURE-PRINCIPLES.md
        └── TERRAFORM-BEST-PRACTICES.md
```

**Step 2: Configure Git Branch Protection**
```yaml
main branch:
  - Require pull request before merging
  - Require at least 1 approval
  - Require status checks to pass (Terraform plans)
  - Require conversation resolution
  - Require linear history
  - Do not allow force pushes
  - Do not allow deletions
```

**Step 3: Set Up Terraform Cloud Workspaces**
```
For each environment (dev, staging, production):
1. Create workspace in Terraform Cloud
2. Link to GitHub repository (main branch)
3. Set working directory: environments/{env}
4. Configure execution mode: Remote
5. Set Terraform version (pin to specific version)
6. Configure VCS triggers:
   - Trigger on main branch only
   - Path filter: environments/{env}/**/*
```

### Phase 2: Workspace Configuration (Week 1-2)

**Development Workspace**
```hcl
# Settings in Terraform Cloud UI
Name: aws-infrastructure-dev
Execution Mode: Remote
Terraform Version: 1.6.0 (pinned)
Working Directory: environments/dev
VCS Branch: main
Auto Apply: Enabled
Terraform Working Directory: environments/dev

# VCS Triggers
Trigger Patterns:
  - environments/dev/**/*
  - modules/**/*  # Also trigger on module changes

# Environment Variables (Sensitive)
AWS_ACCESS_KEY_ID: [Dev AWS Account]
AWS_SECRET_ACCESS_KEY: [Dev AWS Account]
AWS_DEFAULT_REGION: us-east-1

# Terraform Variables
environment: dev
aws_account_id: [Dev Account ID]
```

**Staging Workspace**
```hcl
Name: aws-infrastructure-staging
Auto Apply: Enabled
Notifications: Slack (#infrastructure-staging)

# VCS Triggers - same as dev
```

**Production Workspace**
```hcl
Name: aws-infrastructure-production
Auto Apply: Disabled  # CRITICAL: Manual approval required
Notifications: Slack (#infrastructure-production) + Email

# Apply Method: Manual approval by 2 people
# Sentinel Policies: Enabled (prevent public S3, require encryption, etc.)
```

### Phase 3: Module Development (Week 2-3)

**Create Reusable Modules**
```hcl
# Example: modules/vpc/main.tf
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}
```

**Environment Configuration**
```hcl
# environments/dev/main.tf
terraform {
  required_version = "~> 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  cloud {
    organization = "your-org"
    
    workspaces {
      name = "aws-infrastructure-dev"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "infrastructure"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment = var.environment
  cidr_block  = var.vpc_cidr_block
}

# environments/dev/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

# environments/dev/terraform.tfvars
vpc_cidr_block = "10.0.0.0/16"
```

### Phase 4: Sentinel Policies (Week 3-4)

**Implement Policy as Code**
```hcl
# policies/require-tags.sentinel
import "tfplan/v2" as tfplan

mandatory_tags = ["Environment", "Owner", "ManagedBy"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.mode is "managed" and
    rc.type not in ["aws_iam_role", "aws_iam_policy"] and
    all mandatory_tags as tag {
      rc.change.after.tags contains tag
    }
  }
}

# policies/no-public-s3.sentinel
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_s3_bucket" implies
    rc.change.after.acl is not "public-read" and
    rc.change.after.acl is not "public-read-write"
  }
}

# policies/require-encryption.sentinel
# Enforce encryption for EBS, RDS, S3, etc.
```

### Phase 5: Team Enablement (Week 4)

**Documentation**
- Update TERRAFORM-BEST-PRACTICES.md with team-specific workflows
- Create runbooks for common scenarios
- Document emergency procedures

**Team Training**
- Walkthrough of new workflow
- Practice PRs in dev environment
- Review Terraform Cloud UI
- Emergency hotfix procedures

## Workflow Examples

### Normal Feature Development

```bash
# 1. Create feature branch
git checkout -b feature/add-eks-cluster

# 2. Make changes to dev environment
cd environments/dev
# Edit main.tf to add EKS module reference

# 3. Commit and push
git add .
git commit -m "feat: add EKS cluster to dev environment"
git push origin feature/add-eks-cluster

# 4. Open PR to main
# Terraform Cloud automatically runs speculative plan
# Plan posted as PR comment

# 5. Team reviews PR and plan output
# At least 1 approval required

# 6. Merge PR
# Terraform Cloud automatically applies to dev environment

# 7. Validate in dev, then promote to staging
# Create new branch from main
git checkout -b feature/add-eks-cluster-staging
cd environments/staging
# Copy changes from dev, adjust variables

# 8. Repeat PR process for staging

# 9. After staging validation, promote to production
# Same process, but production requires manual apply in TF Cloud UI
```

### Emergency Production Hotfix

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/fix-security-group

# 2. Make fix ONLY to production environment
cd environments/production
# Edit main.tf

# 3. Fast-track PR process
# Get 2 approvals instead of 1
# Merge to main

# 4. Manual apply in Terraform Cloud UI

# 5. After production fixed, backport to lower environments
cd environments/staging
# Apply same fix
# Commit and PR

cd environments/dev
# Apply same fix
# Commit and PR
```

### Module Updates

```bash
# 1. Create branch for module change
git checkout -b feat/update-vpc-module

# 2. Update module
cd modules/vpc
# Edit main.tf

# 3. Update module version in environments
cd environments/dev
# Update module source version

# 4. Test in dev first
git commit -m "feat: update VPC module with enhanced security"
git push
# Open PR - triggers dev workspace plan

# 5. After dev validation, update staging and prod
cd environments/staging
# Update module version
# Same for production

# 6. Single PR updates all environments
# Dev auto-applies, staging auto-applies, prod requires approval
```

## Consequences

### Positive
- **Simple mental model**: One branch, environments as directories
- **Fast feedback**: Speculative plans on every PR automatically
- **Low operational overhead**: No CI/CD infrastructure to maintain
- **Clear audit trail**: Git history + Terraform Cloud logs
- **Progressive deployment**: Dev → Staging → Prod with appropriate gates
- **Module reuse**: Common patterns defined once, used everywhere
- **Cost-effective**: No additional CI/CD runners needed
- **Scales with team**: Easy to add environments or split workspaces

### Negative
- **Requires discipline**: Developers must be careful which directories they modify
- **Less protection against accidents**: Could theoretically modify prod when intending dev
- **Limited pre-deployment customization**: Can't easily run complex validation before Terraform
- **All environments update together**: PR to main affects all modified directories

### Mitigations for Negatives
1. **Branch protection rules**: Require reviews for all PRs
2. **CODEOWNERS file**: Require specific approvals for production directory
3. **Path-based triggers**: Each workspace only triggers on its directory
4. **Production approval**: Manual apply required for production workspace
5. **Sentinel policies**: Automated policy checks before apply
6. **Clear documentation**: Team training and runbooks
7. **PR templates**: Checklist to verify correct environment modified

## Alternative Approach for Future Consideration

If the team grows significantly (>15 engineers) or needs more complex validation, consider migrating to:

**Option 3: CLI-Driven + GitHub Actions**

This would provide:
- More sophisticated pre-deployment validation
- Integration with additional security scanning tools
- More flexible deployment patterns (blue/green, canary)
- Better support for multi-repo module dependencies

However, this adds significant complexity and should only be considered when the simpler VCS-driven approach becomes a clear bottleneck.

## Review Date

This decision should be reviewed in 6 months (April 2026) or when:
- Team size exceeds 10 engineers
- Number of environments exceeds 5
- Complex pre-deployment requirements emerge (compliance, advanced security)
- Pattern of accidental production modifications emerges
- Team feedback indicates workflow is too restrictive or too risky

## References

- [Terraform Cloud VCS-Driven Workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/ui)
- [Terraform Cloud CLI-Driven Workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/cli)
- [Managing Multiple Terraform Environments](https://spacelift.io/blog/terraform-environments)
- [Terraform VCS Workflows (HashiCorp Blog)](https://www.hashicorp.com/en/blog/which-terraform-workflow-should-i-use-vcs-cli-or-api)
- ADR-001: Terraform State Management Backend

---

**Document Information**
- **Created**: October 28, 2025
- **Author**: Platform Engineering Team
- **Reviewers**: [To be assigned]
- **Status**: Pending Review
- **Version**: 1.0