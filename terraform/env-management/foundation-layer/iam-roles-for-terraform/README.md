# Management Account - Foundation Layer - IAM Roles for Terraform

This workspace creates IAM roles for Terraform Cloud VCS-driven workspaces across development, staging, and production environments using dynamic OIDC credentials.

## Overview

This configuration creates **workspace-specific IAM roles** that follow the principle of least privilege. Each role is scoped to a specific Terraform Cloud workspace and has only the permissions needed for that environment/layer combination.

This workspace:

1. **References the existing OIDC Provider** - Created by `terraform-cloud-oidc-role`
2. **Creates IAM Roles** - Environment and layer-specific roles for VCS workspaces
3. **Defines Policies** - Graduated permissions based on environment criticality

## Architecture

This implements Phase 2 of [ADR-010](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md):

```text
terraform-cloud-oidc-role (Bootstrap)
    │
    │ provisions (using OIDC)
    ▼
┌─────────────────────────────────────────┐
│     iam-roles-for-terraform             │
│     (This Workspace)                    │
│                                         │
│  Creates:                               │
│  • terraform-dev-foundation-cicd-role   │
│  • terraform-staging-foundation-cicd-role│
│  • terraform-prod-foundation-cicd-role  │
└─────────────────────────────────────────┘
    │
    │ used by (OIDC)
    ▼
┌─────────────────────────────────────────┐
│     VCS Terraform Workspaces            │
│                                         │
│  • dev-foundation workspace             │
│  • staging-foundation workspace         │
│  • prod-foundation workspace            │
└─────────────────────────────────────────┘
```

## Prerequisites

### 1. Bootstrap Complete

The `terraform-cloud-oidc-role` workspace must be applied first. This creates:

- The OIDC provider for Terraform Cloud
- The bootstrap role with permissions to create other IAM roles

### 2. Terraform Cloud Workspace

Create a workspace in Terraform Cloud:

- Name: `management-foundation-iam-roles-terraform`
- Configure to use the bootstrap OIDC role

## Setup Instructions

### Step 1: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Update:

- `tfc_organization`: Your Terraform Cloud organization
- `owner`: Your email address
- `tfc_workspace_*`: Names of your environment workspaces

### Step 2: Update Backend Configuration

Edit `backend.tf` and replace `YOUR_TFC_ORG_NAME` with your organization.

### Step 3: Configure Terraform Cloud Workspace

In Terraform Cloud, set these environment variables for this workspace:

```bash
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::ACCOUNT_ID:role/terraform-cloud-oidc-role"
```

### Step 4: Run in Terraform Cloud

Queue a plan and apply in Terraform Cloud. The bootstrap OIDC role will be used to create the workspace-specific roles.

## Configuring VCS Workspaces to Use Their Roles

After this workspace creates the roles, configure each VCS workspace:

### For dev-foundation workspace

```bash
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::ACCOUNT_ID:role/terraform-dev-foundation-cicd-role"
```

### For staging-foundation workspace

```bash
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::ACCOUNT_ID:role/terraform-staging-foundation-cicd-role"
```

### For prod-foundation workspace

```bash
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::ACCOUNT_ID:role/terraform-production-foundation-cicd-role"
```

## Adding New Roles

To add a role for a new workspace (e.g., `dev-platform`):

### 1. Add the module call in `main.tf`

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

### 2. Add the policy in `policies.tf`

```hcl
data "aws_iam_policy_document" "dev_platform_permissions" {
  statement {
    sid    = "EKSManagement"
    effect = "Allow"
    actions = [
      "eks:*",
      # Add specific permissions needed
    ]
    resources = ["*"]
  }
}
```

### 3. Apply this workspace

The bootstrap role will create the new role.

### 4. Configure the new VCS workspace

Set the environment variables to use the new role.

## Permission Levels

| Environment | Permission Level | Session Duration | Notes |
|-------------|------------------|------------------|-------|
| Development | Full CRUD | 2 hours | Can create/delete/modify freely |
| Staging | Create/Modify | 1 hour | Limited delete, testing before prod |
| Production | Read + Restricted Modify | 1 hour | Careful changes, regional restrictions |

## Output Values

After applying, these outputs provide the role ARNs:

```bash
terraform output dev_foundation_cicd_role_arn
terraform output staging_foundation_cicd_role_arn
terraform output prod_foundation_cicd_role_arn
```

## Security Considerations

1. **Workspace Isolation** - Each role trusts only its specific workspace
2. **No Wildcard Trust** - Unlike the bootstrap role, these roles have exact subject claims
3. **Least Privilege** - Permissions scoped to layer and environment needs
4. **Session Duration** - Production roles have shorter sessions
5. **Audit Trail** - All role usage logged in CloudTrail

## References

- [IAM Role Architecture](../../../../docs/explanations/iam-role-architecture.md)
- [ADR-010: AWS IAM Role Structure](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
- [Terraform Cloud Dynamic Credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws)
