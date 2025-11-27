# IAM Role Architecture for Terraform Cloud

This document explains the IAM role strategy used for both human operators and VCS-driven Terraform Cloud workspaces, following the principle of least privilege.

## Overview

Our IAM role architecture follows a layered approach:

1. **Bootstrap OIDC Role** - Provisions other IAM roles
2. **VCS Terraform Roles** - Used by Terraform Cloud workspaces for CI/CD automation
3. **IAM Identity Center** - Provides human access via SSO permission sets

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          BOOTSTRAP (One-time Setup)                         │
│                                                                             │
│   terraform-cloud-oidc-role (Management Account)                           │
│   └── Permissions: Create/manage IAM roles, SSO, OIDC providers            │
│   └── Trust: Terraform Cloud OIDC (any workspace in organization)          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ provisions
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         IAM ROLES FOR AUTOMATION                            │
│                                                                             │
│   terraform-{env}-{layer}-cicd-role                                        │
│   ├── terraform-dev-foundation-cicd-role                                   │
│   ├── terraform-dev-platform-cicd-role                                     │
│   ├── terraform-staging-foundation-cicd-role                               │
│   ├── terraform-production-foundation-cicd-role                            │
│   └── etc.                                                                  │
│                                                                             │
│   Trust: Terraform Cloud OIDC (specific project/workspace)                 │
│   Permissions: Limited to what that environment/layer needs                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ used by
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     TERRAFORM CLOUD VCS WORKSPACES                          │
│                                                                             │
│   project: development                                                      │
│   ├── workspace: dev-foundation → uses terraform-dev-foundation-cicd-role  │
│   ├── workspace: dev-platform   → uses terraform-dev-platform-cicd-role    │
│   └── workspace: dev-apps       → uses terraform-dev-applications-cicd-role│
│                                                                             │
│   project: production                                                       │
│   ├── workspace: prod-foundation → uses terraform-prod-foundation-cicd-role│
│   └── etc.                                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## The Bootstrap OIDC Role

The `terraform-cloud-oidc-role` is your **bootstrap role**. It was created manually (or with local credentials) and has elevated permissions specifically for:

1. **Managing the OIDC Provider** - Create/update the Terraform Cloud OIDC identity provider
2. **Creating IAM Roles** - Provision workspace-specific roles with appropriate permissions
3. **Managing IAM Identity Center** - Set up SSO groups and permission sets for human access
4. **Self-management** - Update its own policies as needed

### Trust Policy

The bootstrap role trusts Terraform Cloud OIDC tokens from **any workspace** in your organization:

```hcl
Condition = {
  StringLike = {
    "app.terraform.io:sub" = "organization:${org}:project:*:workspace:*:run_phase:*"
  }
}
```

### What It Can Provision

The bootstrap role can create:

- `terraform-cloud-*` roles (self-management)
- `terraform-*-*-cicd-role` (VCS workspace automation roles)
- `terraform-*-*-human-role` (break-glass human access roles)
- IAM policies prefixed with `terraform-*`

## VCS Terraform Workspace Roles

These are the roles that individual Terraform Cloud workspaces use for day-to-day operations. Each role is scoped to:

- **Environment**: dev, staging, production
- **Layer**: foundation, platform, application
- **Context**: cicd (automated) or human (break-glass)

### Role Naming Convention

```text
terraform-{environment}-{layer}-{context}-role

Examples:
- terraform-dev-foundation-cicd-role
- terraform-staging-platform-cicd-role
- terraform-production-application-cicd-role
```

### Trust Policy (Workspace-Specific)

Each role trusts only a **specific workspace**:

```hcl
Condition = {
  StringEquals = {
    "app.terraform.io:sub" = "organization:${org}:project:${project}:workspace:${workspace}:run_phase:*"
  }
}
```

This ensures that only the intended workspace can assume the role.

### Permission Gradation

| Environment | Permission Level | Session Duration |
|-------------|------------------|------------------|
| Development | Full create/delete/modify | 2 hours |
| Staging | Create/modify, limited delete | 1 hour |
| Production | Primarily read, restricted modify | 1 hour |

## IAM Identity Center (Human Access)

Human access is managed separately through **IAM Identity Center (SSO)**, not through Terraform Cloud OIDC roles. The `iam-roles-for-people` module creates:

1. **Identity Store Groups** - Administrators, Platform-Engineers, ReadOnly
2. **Permission Sets** - AdministratorAccess, PlatformEngineerAccess, ReadOnlyAccess
3. **Account Assignments** - Links groups to accounts with permission sets

Humans log in via AWS SSO portal and assume permission sets—they don't use the Terraform OIDC roles directly.

## How to Configure a New VCS Workspace

When you create a new Terraform Cloud workspace that needs to provision AWS resources:

### Step 1: Create the IAM Role

Add the role to `iam-roles-for-terraform/main.tf`:

```hcl
module "dev_platform_cicd_role" {
  source = "../../../terraform-modules/terraform-oidc-role"

  role_name          = "terraform-dev-platform-cicd-role"
  environment        = "dev"
  layer              = "platform"
  context            = "cicd"
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.terraform_cloud.arn
  oidc_provider_url  = local.tfc_hostname
  oidc_audience      = local.tfc_audience
  cicd_subject_claim = "organization:${var.tfc_organization}:project:development:workspace:dev-platform:run_phase:*"
  session_duration   = 7200

  attach_readonly_policy = true
  custom_policy_json     = data.aws_iam_policy_document.dev_platform_permissions.json

  tags = local.common_tags
}
```

### Step 2: Define the Policy

Add the policy to `iam-roles-for-terraform/policies.tf`:

```hcl
data "aws_iam_policy_document" "dev_platform_permissions" {
  statement {
    sid    = "EKSManagement"
    effect = "Allow"
    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      # ... specific permissions for platform layer
    ]
    resources = ["*"]
  }
}
```

### Step 3: Apply with Bootstrap Role

Run the `iam-roles-for-terraform` workspace (which uses the bootstrap OIDC role) to create the new role.

### Step 4: Configure the New Workspace

In Terraform Cloud, configure the new workspace to use its role:

1. Go to workspace settings → Variables
2. Add environment variables:

   ```bash
   TFC_AWS_PROVIDER_AUTH = "true"
   TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::ACCOUNT_ID:role/terraform-dev-platform-cicd-role"
   ```

3. If using multiple accounts, also add:

   ```bash
   AWS_REGION = "ap-southeast-2"
   ```

### Step 5: Configure Provider in Terraform Code

In your workspace's Terraform code:

```hcl
terraform {
  cloud {
    organization = "YourOrg"
    workspaces {
      name = "dev-platform"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
  # No credentials needed - uses OIDC from TFC_AWS_RUN_ROLE_ARN
}
```

## Architecture Diagram

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TERRAFORM CLOUD                                    │
│                                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌─────────────────────┐│
│  │ mgmt-foundation-oidc │  │ dev-foundation       │  │ prod-platform       ││
│  │ (Bootstrap Workspace)│  │ (VCS Workspace)      │  │ (VCS Workspace)     ││
│  └──────────┬───────────┘  └──────────┬───────────┘  └──────────┬──────────┘│
│             │                         │                         │           │
└─────────────┼─────────────────────────┼─────────────────────────┼───────────┘
              │ OIDC                    │ OIDC                    │ OIDC
              ▼                         ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS ACCOUNT(S)                                  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    OIDC Provider (app.terraform.io)                    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│              ┌─────────────────────┼─────────────────────┐                  │
│              ▼                     ▼                     ▼                  │
│  ┌──────────────────────┐ ┌──────────────────┐ ┌──────────────────────────┐│
│  │terraform-cloud-oidc  │ │terraform-dev-    │ │terraform-production-     ││
│  │-role                 │ │foundation-cicd-  │ │platform-cicd-role        ││
│  │                      │ │role              │ │                          ││
│  │Permissions:          │ │Permissions:      │ │Permissions:              ││
│  │• Create IAM roles    │ │• IAM (terraform-*)│ │• EKS management         ││
│  │• Manage SSO          │ │• OIDC read       │ │• VPC networking          ││
│  │• Manage OIDC         │ │• S3 state        │ │• Read-only baseline      ││
│  └──────────────────────┘ └──────────────────┘ └──────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Security Benefits

1. **No Long-Lived Credentials** - OIDC tokens are short-lived and auto-rotate
2. **Workspace Isolation** - Each workspace can only assume its designated role
3. **Least Privilege** - Roles have only the permissions needed for their scope
4. **Audit Trail** - CloudTrail logs all `AssumeRoleWithWebIdentity` events
5. **No Secret Rotation** - No API keys to manage or rotate

## Dependency Order

When setting up from scratch:

1. **terraform-cloud-oidc-role** (bootstrap) - Created first, manually or with local credentials
2. **iam-roles-for-people** - Uses bootstrap role to create SSO resources
3. **iam-roles-for-terraform** - Uses bootstrap role to create workspace roles
4. **Environment workspaces** - Use their specific roles created in step 3

## Related Documentation

- [ADR-010: AWS IAM Role Structure](../reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
- [Terraform Cloud OIDC Setup Checklist](../how-to-guides/terraform-cloud-oidc-setup-checklist.md)
- [Terraform Cloud AWS Authentication](../how-to-guides/terraform-cloud-aws-authentication.md)

