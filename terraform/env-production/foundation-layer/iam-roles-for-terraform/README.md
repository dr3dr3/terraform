# Production Account - Foundation Layer - IAM Roles for Terraform

This workspace creates IAM roles in the **Production AWS account** that allow Terraform Cloud workspaces to provision resources.

## Overview

This configuration:

1. **Creates an OIDC Provider** in the production account for Terraform Cloud
2. **Creates Layer-Specific IAM Roles** with appropriate permissions:
   - `terraform-prod-foundation-cicd-role` - For foundation layer workspaces
   - `terraform-prod-platform-cicd-role` - For platform layer workspaces (EKS, VPC)
   - `terraform-prod-applications-cicd-role` - For application layer workspaces

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TERRAFORM CLOUD                                    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐     │
│  │ prod-foundation-*  │  │ prod-platform-*    │  │ prod-applications-*│     │
│  │ workspaces         │  │ workspaces         │  │ workspaces         │     │
│  └─────────┬──────────┘  └─────────┬──────────┘  └─────────┬──────────┘     │
│            │                       │                       │                 │
└────────────┼───────────────────────┼───────────────────────┼─────────────────┘
             │ OIDC                  │ OIDC                  │ OIDC
             ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PRODUCTION AWS ACCOUNT                                  │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                   OIDC Provider (app.terraform.io)                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│            ┌───────────────────────┼───────────────────────┐                │
│            ▼                       ▼                       ▼                │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │ terraform-prod-  │  │ terraform-prod-  │  │ terraform-prod-  │          │
│  │ foundation-cicd  │  │ platform-cicd    │  │ applications-    │          │
│  │ -role            │  │ -role            │  │ cicd-role        │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Bootstrap Requirements

This workspace requires **initial bootstrap** because:

- It creates the OIDC provider that TFC uses to authenticate
- You need credentials for the production account BEFORE OIDC is set up

**Bootstrap Options:**

1. **AWS SSO** - Login to production account and run locally:

   ```bash
   aws sso login --profile production
   export AWS_PROFILE=production
   terraform init
   terraform apply
   ```

2. **Temporary Access Keys** - Set in Terraform Cloud workspace (remove after bootstrap)

3. **Cross-Account Role** - Use management account to assume a role in production (if configured)

### After Bootstrap

Once this workspace has been applied, configure the workspace to use OIDC:

1. Go to Terraform Cloud workspace settings
2. Set environment variables:

   ```text
   TFC_AWS_PROVIDER_AUTH = "true"
   TFC_AWS_RUN_ROLE_ARN  = "<production-account-id>:role/terraform-prod-foundation-cicd-role"
   ```

3. Remove any temporary access keys

## Role Permissions

| Role | Layer | Permissions |
|------|-------|-------------|
| `terraform-prod-foundation-cicd-role` | Foundation | IAM roles/policies, OIDC providers |
| `terraform-prod-platform-cicd-role` | Platform | VPC, EKS, KMS, CloudWatch Logs |
| `terraform-prod-applications-cicd-role` | Applications | Lambda, API Gateway, S3, DynamoDB, SNS/SQS |

All roles include `ReadOnlyAccess` as a baseline.

## Workspace Trust Policy

Each role trusts only workspaces that match specific patterns:

- **Foundation role**: Trusts workspaces with `foundation` in the name
- **Platform role**: Trusts workspaces with `platform` in the name
- **Applications role**: Trusts workspaces with `application` in the name

This ensures workspaces can only assume roles appropriate for their layer.

## Configuring Other Workspaces

After this workspace is applied, configure other TFC workspaces in the production project:

### Example: EKS Platform Workspace

```text
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::<production-account-id>:role/terraform-prod-platform-cicd-role"
```

## Output Values

After applying:

```bash
terraform output foundation_cicd_role_arn
terraform output platform_cicd_role_arn
terraform output applications_cicd_role_arn
```

## Security Considerations

1. **Account Isolation** - Roles exist in production account, can only access production resources
2. **Layer Isolation** - Each role trusts only workspaces for its layer
3. **Least Privilege** - Each role has permissions scoped to its layer's needs
4. **No Wildcards in Trust** - Workspace name patterns prevent unauthorized access
5. **ReadOnly Baseline** - All roles can read but have restricted write permissions

## Related Documentation

- [ADR-010: AWS IAM Role Structure](../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
- [Terraform Cloud Dynamic Credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws)
- [AWS Accounts Reference](../../../docs/reference/aws-accounts.md)
