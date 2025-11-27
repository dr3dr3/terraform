# Terraform Cloud AWS Authentication - Complete Review

## Executive Summary

Your Terraform code is **properly configured for Terraform Cloud VCS-driven workflows**, but **AWS authentication is not yet set up**. This means:

- ✅ Your code pushes to GitHub and triggers Terraform Cloud plans
- ❌ Terraform Cloud **cannot authenticate to AWS** to execute the plans
- ❌ You'll get authentication errors when Terraform Cloud tries to provision resources

This guide provides everything needed to complete the authentication setup using **OIDC (OpenID Connect)**, which is the most secure, modern approach.

## Current Architecture

```bash
GitHub Repository
       ↓ (webhook on push)
Terraform Cloud (TFC)
       ↓ (needs to authenticate)
AWS Account (Management)
       ↓
IAM Identity Center Resources
```

## The Problem

When you push code to GitHub:

1. ✅ GitHub webhook triggers Terraform Cloud workspace
2. ✅ Terraform Cloud downloads your code and runs `terraform plan`
3. ❌ **FAILS HERE**: Terraform Cloud tries to call AWS API but has no credentials
4. ❌ Error: `AWS credentials not configured` or `Access denied`

## The Solution

Set up **OIDC authentication** between Terraform Cloud and AWS:

```bash
Terraform Cloud
       ↓ (presents OIDC token)
AWS OIDC Provider
       ↓ (validates token)
IAM Role (terraform-cloud-oidc-role)
       ↓ (grants temporary credentials)
Terraform Cloud
       ↓ (now has credentials)
AWS API (provision resources)
```

## Why OIDC?

| Method | Security | Effort | Best For |
|--------|----------|--------|----------|
| **IAM User** | ❌ Poor | ⭐ Easy | Legacy only |
| **API Keys** | ⚠️ Risky | ⭐ Easy | Not recommended |
| **OIDC** | ✅ Excellent | ⭐⭐ Moderate | **Production (recommended)** |

OIDC is:

- **Zero stored credentials** in Terraform Cloud (instead, uses tokens)
- **Short-lived tokens** (expire after use)
- **Automatic rotation** (no manual key rotation needed)
- **Audit trail** via AWS CloudTrail
- **Industry standard** (how GitHub Actions, AWS CodeBuild, etc. do it)

## What You Need to Do

### Phase 1: AWS Setup (10 minutes)

Create three resources in your management account:

1. **OIDC Provider** - Tells AWS to trust Terraform Cloud's tokens
2. **IAM Role** - Defines permissions for Terraform Cloud
3. **Inline Policy** - Grants permissions to manage IAM Identity Center

### Phase 2: Terraform Cloud Setup (5 minutes)

Configure three environment variables:

1. `TFC_AWS_PROVIDER_AUTH` = `"true"` (enable OIDC)
2. `TFC_AWS_ROLE_ARN` = your role ARN
3. `TFC_AWS_ROLE_SESSION_NAME` = session identifier

### Phase 3: Test (5 minutes)

Push a small change to verify it works.

## Implementation Options

### Option A: Use AWS CLI (Fastest)

```bash
# Copy-paste commands from:
# /workspace/docs/how-to-guides/terraform-cloud-oidc-setup-commands.md
```

**Pros:** Fast, straightforward
**Cons:** Manual, not version-controlled

### Option B: Use Terraform (Best Practice)

```bash
# Use the provided Terraform configuration:
# /workspace/terraform/env-management/foundation-layer/terraform-cloud-oidc-role/main.tf
```

**Pros:** Version-controlled, repeatable, documented
**Cons:** Takes a few more minutes

## Key Security Principles

Your setup will follow:

1. **Least Privilege**: Role only grants IAM Identity Center permissions (not full admin)
2. **Workspace Isolation**: Trust policy restricts to your "Datafaced" organization
3. **Automatic Rotation**: No stored credentials (OIDC tokens expire after use)
4. **Audit Trail**: CloudTrail logs all OIDC usage
5. **No Secrets**: No API keys to protect or rotate

## Files Created for You

| File | Purpose |
|------|---------|
| `/workspace/docs/how-to-guides/terraform-cloud-aws-authentication.md` | **📖 Detailed implementation guide** |
| `/workspace/docs/how-to-guides/terraform-cloud-oidc-setup-checklist.md` | **✅ Step-by-step checklist** |
| `/workspace/docs/how-to-guides/terraform-cloud-oidc-setup-commands.md` | **⌨️ AWS CLI commands** |
| `/workspace/terraform/env-management/foundation-layer/terraform-cloud-oidc-role/main.tf` | **🏗️ Terraform code for OIDC setup** |

## Quick Start (5-Step Process)

### Step 1: Create OIDC Resources in AWS

Run these AWS CLI commands (or use Terraform):

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url "https://app.terraform.io" \
  --client-id-list "aws.workload.identity" \
  --thumbprint-list "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"

# Create role with trust policy (see detailed guide for full policy)
# Create inline policy granting IAM Identity Center permissions
```

**Full commands:** See `/workspace/docs/how-to-guides/terraform-cloud-oidc-setup-commands.md`

### Step 2: Get Your Role ARN

```bash
aws iam get-role --role-name terraform-cloud-oidc-role \
  --query 'Role.Arn' --output text
```

Copy this ARN - you'll need it in Step 3.

### Step 3: Configure Terraform Cloud

1. Go to [https://app.terraform.io/app/Datafaced/settings/varsets](https://app.terraform.io/app/Datafaced/settings/varsets)
2. Create new variable set: `AWS Provider Credentials`
3. Add these environment variables:
   - `TFC_AWS_PROVIDER_AUTH` = `true`
   - `TFC_AWS_ROLE_ARN` = `<your-role-arn>`
   - `TFC_AWS_ROLE_SESSION_NAME` = `terraform-cloud-session`
4. Apply to workspace: `management-foundation-iam-roles-for-people`

### Step 4: Push Test Commit

```bash
cd /workspace/terraform/env-management/foundation-layer/iam-roles-for-people
git add . && git commit -m "test: oidc auth" && git push origin main
```

### Step 5: Verify in Terraform Cloud

- Watch the plan run: [https://app.terraform.io/app/Datafaced/workspaces/management-foundation-iam-roles-for-people/runs](https://app.terraform.io/app/Datafaced/workspaces/management-foundation-iam-roles-for-people/runs)
- Should see AWS API calls in logs
- No authentication errors = success!

## Validation Checklist

After setup, verify:

- [ ] Terraform Cloud run completes without auth errors
- [ ] CloudTrail shows `AssumeRoleWithWebIdentity` events from `app.terraform.io`
- [ ] Events show role: `terraform-cloud-oidc-role`
- [ ] Can review and approve plan in Terraform Cloud
- [ ] Apply succeeds without credentials errors

## Troubleshooting

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| "Access denied" in TFC logs | OIDC role doesn't have permissions | Add IAM Identity Center permissions to role |
| "Not authorized to assume role" | Trust policy condition mismatch | Verify organization name is "Datafaced" |
| "OIDC provider not found" | Provider URL is wrong | Use exact URL: `https://app.terraform.io` |
| Works locally, fails in TFC | Using different credentials | Ensure OIDC role has all SSO permissions |

See detailed guide for more troubleshooting.

## Related Documentation

**Architecture Decisions:**

- [ADR-001: Terraform State Management](../../reference/architecture-decision-register/ADR-001-terraform-state-management.md) - Why Terraform Cloud was chosen
- [ADR-010: AWS IAM Role Structure](../../reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md) - OIDC role design principles

**Implementation Guides:**

- [Detailed Setup Guide](terraform-cloud-aws-authentication.md) - Complete walkthrough
- [Setup Checklist](terraform-cloud-oidc-setup-checklist.md) - Step-by-step checklist
- [AWS CLI Commands](terraform-cloud-oidc-setup-commands.md) - Copy-paste ready commands

**Official Documentation:**

- [Terraform Cloud OIDC Documentation](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)

## Next Steps

1. **Today**: Review this summary and choose Option A (AWS CLI) or Option B (Terraform)
2. **This week**: Execute Phase 1 (AWS setup) and Phase 2 (Terraform Cloud config)
3. **Before next deploy**: Test with Phase 3 (push test commit)
4. **Ongoing**: Monitor CloudTrail for OIDC usage, review quarterly

## Support

For issues:

1. **Check logs**: Review Terraform Cloud run logs for exact error
2. **Check CloudTrail**: Look for AssumeRoleWithWebIdentity events and errors
3. **Check trust policy**: Verify OIDC provider details in AWS Console
4. **See troubleshooting**: Refer to detailed guide's troubleshooting section

---

**Document Version:** 1.0  
**Last Updated:** November 26, 2025  
**Confidence Level:** High - Based on AWS/TFC official documentation
