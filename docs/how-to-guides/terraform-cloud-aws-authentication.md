# Terraform Cloud - AWS Authentication Setup Guide

## Overview

Your Terraform code is configured for **Terraform Cloud VCS-driven workflows**, but AWS authentication for Terraform Cloud is not yet configured. This guide walks you through the complete setup.

## Two Authentication Flows

You have **two different authentication scenarios**:

### 1. Terminal/Local Execution (Currently Working ✅)

- Running `terraform plan/apply` from your machine
- Uses your AWS SSO profile (`Admin-Dev`)
- Credentials from: `~/.aws/config` and `~/.aws/sso/cache/`

### 2. Terraform Cloud VCS-Driven (Not Configured ❌)

- Automatic plan/apply when you push to Git
- Terraform Cloud needs to authenticate to AWS
- Credentials must come from: OIDC role assumption (recommended)

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│ Your GitHub Repository                                       │
│ (Push code → Webhook to Terraform Cloud)                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Terraform Cloud (app.terraform.io)                          │
│ - organization: "Datafaced"                                 │
│ - workspace: "management-foundation-iam-roles-for-people"   │
└────────────────────┬────────────────────────────────────────┘
                     │ Needs AWS credentials via OIDC
                     │ (not passwords/API keys!)
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ AWS Account (Management)                                    │
│ - OIDC Provider: https://app.terraform.io                  │
│ - IAM Role: terraform-cloud-oidc-role                       │
│ - Permissions: SSO/IAM Identity Center management           │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Create AWS OIDC Provider and Role

First, set up the OIDC trust relationship in AWS. Create these resources in your management account:

```hcl
# In a Terraform configuration in your management account
# (or create manually in AWS Console)

resource "aws_iam_openid_connect_provider" "terraform_cloud" {
  url             = "https://app.terraform.io"
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = {
    Name = "terraform-cloud-oidc-provider"
  }
}

resource "aws_iam_role" "terraform_cloud_oidc" {
  name = "terraform-cloud-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.terraform_cloud.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "app.terraform.io:aud" = "aws.workload.identity"
          }
          StringLike = {
            "app.terraform.io:sub" = "organization:Datafaced:project:*:workspace:*:run_phase:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "terraform-cloud-oidc-role"
  }
}

resource "aws_iam_role_policy" "terraform_cloud" {
  name = "terraform-cloud-policy"
  role = aws_iam_role.terraform_cloud_oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageIAMIdentityCenter"
        Effect = "Allow"
        Action = [
          "identitystore:*",
          "sso:*",
          "ssoadmin:*"
        ]
        Resource = "*"
      }
    ]
  })
}

output "role_arn" {
  value = aws_iam_role.terraform_cloud_oidc.arn
}
```

**Key Points:**

- The thumbprint `9e99a48a9960b14926bb7f3b02e22da2b0ab7280` is Terraform Cloud's official certificate
- The condition restricts the role to your "Datafaced" organization and specific workspaces
- Permissions are scoped to IAM Identity Center operations only (least privilege)

### Step 2: Create Terraform Cloud Variable Set

In Terraform Cloud, you need to tell it which role to assume. Create an environment variable set:

**In Terraform Cloud UI:**

1. Go to `https://app.terraform.io/app/Datafaced/settings/varsets`
2. Click **"Create variable set"**
3. Name: `AWS Provider Credentials`
4. Scope: Select your workspace (`management-foundation-iam-roles-for-people`)
5. Add these variables:

```text
# Required environment variables
TFC_AWS_PROVIDER_AUTH = "true"
TFC_AWS_RUN_ROLE_ARN = "arn:aws:iam::YOUR_ACCOUNT_ID:role/terraform-cloud-oidc-role"
```

### Step 3: Configure Your Terraform Provider (No Changes Needed!)

With dynamic credentials, **you don't need to modify your provider block**. Terraform Cloud automatically injects AWS credentials via environment variables.

Your provider can be as simple as:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "Management"
    }
  }
}
```

Terraform Cloud handles authentication automatically when `TFC_AWS_PROVIDER_AUTH` is set to `true`.

### Step 4: Configure Terraform Cloud Workspace

In Terraform Cloud, configure the workspace to use OIDC:

**Via Terraform Cloud UI:**

1. Navigate to your workspace settings
2. Go to **Variables** tab
3. Add environment variables:

```text
TFC_AWS_PROVIDER_AUTH  = true
TFC_AWS_RUN_ROLE_ARN   = arn:aws:iam::YOUR_ACCOUNT_ID:role/terraform-cloud-oidc-role
```

**Alternatively, via Terraform Code:**

```hcl
resource "tfe_workspace_variable_set" "aws_auth" {
  variable_set_id = tfe_variable_set.aws_credentials.id
  workspace_id    = tfe_workspace.main.id
}

resource "tfe_variable_set" "aws_credentials" {
  organization = "Datafaced"
  name         = "AWS Provider Auth"
  description  = "AWS OIDC authentication for Terraform Cloud"
}

resource "tfe_variable" "aws_provider_auth" {
  variable_set_id = tfe_variable_set.aws_credentials.id
  key             = "TFC_AWS_PROVIDER_AUTH"
  value           = "true"
  category        = "env"
  sensitive       = false
}

resource "tfe_variable" "aws_run_role_arn" {
  variable_set_id = tfe_variable_set.aws_credentials.id
  key             = "TFC_AWS_RUN_ROLE_ARN"
  value           = "arn:aws:iam::YOUR_ACCOUNT_ID:role/terraform-cloud-oidc-role"
  category        = "env"
  sensitive       = false
}
```

### Step 5: Test the Configuration

**Push a small change to your Git repository:**

```bash
cd /workspace/terraform/env-management/foundation-layer/iam-roles-for-people

# Make a minor change (e.g., comment update)
# Commit and push
git add .
git commit -m "test: terraform cloud oidc auth"
git push origin main
```

**Monitor in Terraform Cloud:**

1. Go to your workspace in Terraform Cloud
2. Click the latest run
3. Watch the "Planning" phase
4. Check logs for AWS API calls (should see no authentication errors)
5. Review the plan and approve if correct

**Expected Success Indicators:**

- ✅ Plan completes without authentication errors
- ✅ AWS API calls are visible in logs
- ✅ CloudTrail shows `AssumeRoleWithWebIdentity` from Terraform Cloud
- ✅ No "access denied" errors

### Step 6: Verify CloudTrail Logs

Confirm that OIDC authentication is working:

```bash
# Check recent AssumeRoleWithWebIdentity calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-items 5 \
  --region ap-southeast-2 \
  --query 'Events[*].[EventTime,Username,EventName,CloudTrailEvent]' \
  --output table
```

You should see entries like:

```text
app.terraform.io | AssumeRoleWithWebIdentity | terraform-cloud-oidc-role
```

## Security Best Practices

### 1. Scope Permissions Carefully

The role should only have permissions needed for your specific workspace:

```hcl
# More restrictive: only IAM Identity Center
Statement = [
  {
    Effect = "Allow"
    Action = [
      "identitystore:*",
      "ssoadmin:*",
      "sso:*"
    ]
    Resource = "*"
  }
]

# DON'T do this (overly permissive)
# Action = ["*"]
# Resource = "*"
```

### 2. Restrict Workspace Access

In the trust policy, only allow specific workspaces:

```hcl
StringLike = {
  "app.terraform.io:sub" = [
    "organization:Datafaced:project:*:workspace:management-foundation-iam-roles-for-people:*",
    # Add other workspaces if needed
  ]
}
```

### 3. Enable CloudTrail Monitoring

Monitor for unexpected role assumptions:

```bash
# Create CloudWatch alarm for unexpected usage
aws cloudtrail put-event-selectors \
  --trail-name terraform-cloud-audit \
  --event-selectors ReadWriteType=All,IncludeManagementEvents=true
```

### 4. Regular Access Reviews

- Review who has Terraform Cloud access quarterly
- Check CloudTrail logs for suspicious patterns
- Rotate session names periodically

## Troubleshooting

### Issue: "InvalidAction: The action is not supported for oidc provider"

**Cause:** The OIDC provider URL or client ID is incorrect

**Fix:**

- Verify URL is exactly: `https://app.terraform.io`
- Verify client ID is: `aws.workload.identity`
- Verify thumbprint is: `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`

### Issue: "AssumeRoleWithWebIdentity: Not authorized to perform: sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy condition doesn't match the incoming request

**Fix:**

- Check the actual subject value in CloudTrail
- Ensure your organization name is correct ("Datafaced")
- Verify workspace name matches exactly

### Issue: "Access Denied" when Terraform runs in cloud

**Cause:** The role doesn't have required permissions

**Fix:**

1. Check which resource Terraform is trying to access
2. Add necessary permissions to the role policy
3. Use least privilege: add only what's needed
4. Test with `terraform plan` first before applying

### Issue: Works locally but fails in Terraform Cloud

**Cause:** Different credentials are being used

**Fix:**

- Terraform Cloud uses the OIDC role (not your SSO profile)
- Local uses your SSO credentials
- Ensure the OIDC role has all permissions that your SSO profile has

## Managing Multiple Workspaces

If you have multiple workspaces, you can:

### Option 1: Shared Role (Simpler)

- All workspaces use the same `terraform-cloud-oidc-role`
- Role has union of all required permissions
- Easier to manage, less restrictive

### Option 2: Workspace-Specific Roles (More Secure)

- Create separate role per workspace
- Each role has minimal required permissions
- More complex to maintain, better least privilege

```hcl
# Workspace-specific example
StringLike = {
  "app.terraform.io:sub" = [
    "organization:Datafaced:project:*:workspace:management-foundation-iam-roles-for-people:*",
    "organization:Datafaced:project:*:workspace:dev-foundation-iam:*",
    "organization:Datafaced:project:*:workspace:prod-foundation-iam:*",
  ]
}
```

## Reference Files

- Your Terraform configuration: `/workspace/terraform/env-management/foundation-layer/iam-roles-for-people/`
- Backend configuration: `backend.tf` (contains Terraform Cloud cloud block)
- Provider configuration: `main.tf` or `backend.tf`

## Next Steps

1. ✅ Create OIDC provider and role in AWS
2. ✅ Configure Terraform Cloud variable set
3. ✅ Update provider configuration
4. ✅ Push test commit to trigger Terraform Cloud run
5. ✅ Verify successful OIDC authentication
6. ✅ Monitor CloudTrail for OIDC calls
7. ✅ Set up alerts for failed AssumeRole attempts

## Related Documentation

- [ADR-001: Terraform State Management](../reference/architecture-decision-register/ADR-001-terraform-state-management.md) - Explains why Terraform Cloud was chosen
- [ADR-010: AWS IAM Role Structure](../reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md) - Details on OIDC role structure
- [Terraform Cloud OIDC Documentation](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
- [AWS IAM OIDC Provider Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)

## Support

For issues or questions:

1. Check CloudTrail logs for authentication errors
2. Review Terraform Cloud run logs for detailed error messages
3. Verify OIDC provider configuration in AWS Console
4. Test with `aws sts assume-role-with-web-identity` locally
