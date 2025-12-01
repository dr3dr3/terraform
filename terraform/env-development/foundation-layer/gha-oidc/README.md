# GitHub Actions OIDC Provider and IAM Role - Development Account

This Terraform configuration creates the GitHub Actions OIDC provider and IAM role in the **development AWS account**.

## Why This Exists in the Development Account

In a multi-account AWS setup, the OIDC provider must exist in the **same AWS account** where GitHub Actions needs to assume a role. This is because:

1. GitHub Actions requests an OIDC token from GitHub
2. GitHub Actions calls `sts:AssumeRoleWithWebIdentity` against the target AWS account
3. AWS STS validates the OIDC token against the OIDC provider **in that account**
4. If the provider doesn't exist in that account, authentication fails

```text
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                       │
│              (requests OIDC token from GitHub)                   │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Development AWS Account                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │           OIDC Provider (this configuration)            │    │
│  │   arn:aws:iam::DEV_ACCOUNT:oidc-provider/              │    │
│  │       token.actions.githubusercontent.com               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                               │                                  │
│                               ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │          IAM Role: github-actions-dev-platform          │    │
│  │   - Trusts the OIDC provider                           │    │
│  │   - Has permissions for EKS, VPC, IAM, etc.            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                               │                                  │
│                               ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              EKS Cluster (platform layer)               │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. Access to the **development AWS account** with administrative permissions
2. Terraform Cloud workspace configured with credentials for the development account

## Deployment

### Option 1: Via Terraform Cloud (Recommended for ongoing management)

1. Create the Terraform Cloud workspace `development-foundation-gha-oidc`
2. Configure the workspace with AWS credentials for the development account:
   - Set `TFC_AWS_PROVIDER_AUTH = true`
   - Set `TFC_AWS_RUN_ROLE_ARN` to a bootstrap role in the dev account
3. Trigger a run

### Option 2: Local Bootstrap (For initial setup)

```bash
# Ensure you're authenticated to the DEVELOPMENT AWS account
aws sts get-caller-identity
# Should show the development account ID, NOT the management account

# Comment out the cloud backend temporarily for local state
# Then run:
terraform init
terraform plan
terraform apply
```

## After Deployment

Once this is deployed, get the role ARN:

```bash
terraform output github_actions_dev_platform_role_arn
```

Add this to your GitHub repository secrets:

- **Secret name:** `AWS_ROLE_ARN_DEV_PLATFORM`
- **Secret value:** The ARN from the output above

## Related Resources

- [ADR-013: GitHub Actions OIDC for EKS](../../../../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md)
- [EKS Auto Mode Configuration](../../platform-layer/eks-auto-mode/)
- [GitHub Actions Workflow](../../../../.github/workflows/terraform-dev-platform-eks.yml)
