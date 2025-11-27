# Terraform Cloud + AWS OIDC Setup Checklist

## Quick Reference

Your Terraform code is set up for **Terraform Cloud VCS-driven workflows** but needs AWS authentication configuration. Follow this checklist to complete the setup.

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Terraform Cloud workspace | ✅ Configured | `management-foundation-iam-roles-for-people` |
| AWS SSO (Terminal execution) | ✅ Working | Uses `Admin-Dev` profile locally |
| OIDC Provider in AWS | ❌ Missing | Need to create |
| OIDC Role in AWS | ❌ Missing | Need to create |
| Terraform Cloud env vars | ❌ Missing | Need to configure |
| Provider configuration | ⚠️ Partial | May need updates for OIDC |

## Implementation Checklist

### Phase 1: AWS Setup (Complete in Management Account)

- [ ] **Create OIDC Provider**
  - URL: `https://app.terraform.io`
  - Client ID: `aws.workload.identity`
  - Thumbprint: `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`

- [ ] **Create IAM Role** (`terraform-cloud-oidc-role`)
  - [ ] Trust policy configured with OIDC provider
  - [ ] Trust policy restricted to organization: `Datafaced`
  - [ ] Trust policy restricted to workspaces

- [ ] **Attach Role Policy**
  - [ ] Permissions for `identitystore:*`
  - [ ] Permissions for `ssoadmin:*`
  - [ ] Permissions for `sso:*`

- [ ] **Note the Role ARN**
  - Example: `arn:aws:iam::123456789012:role/terraform-cloud-oidc-role`

### Phase 2: Terraform Cloud Configuration

- [ ] **Create Variable Set** named `AWS Provider Credentials`
  - [ ] Scope to workspace: `management-foundation-iam-roles-for-people`
  - [ ] Add variable: `TFC_AWS_PROVIDER_AUTH = "true"`
  - [ ] Add variable: `TFC_AWS_RUN_ROLE_ARN = "<your-role-arn>"`

### Phase 3: Test Configuration

- [ ] **Test Configuration**
  - [ ] Push small change to trigger Terraform Cloud run
  - [ ] Verify plan completes without authentication errors
  - [ ] Check Terraform Cloud logs for AWS API calls

### Phase 4: Verification

- [ ] **Check CloudTrail**
  - [ ] Look for `AssumeRoleWithWebIdentity` events
  - [ ] Verify source is `app.terraform.io`
  - [ ] Verify role name is `terraform-cloud-oidc-role`

- [ ] **Test First Apply**
  - [ ] Review plan carefully
  - [ ] Approve and apply
  - [ ] Monitor for any permission errors

## Key Files to Update

1. **AWS Infrastructure** (new)
   - Create OIDC provider and role (see detailed guide)

2. **Terraform Code** (if needed)
   - `/workspace/terraform/env-management/foundation-layer/iam-roles-for-people/backend.tf`
   - `/workspace/terraform/env-management/foundation-layer/iam-roles-for-people/main.tf` (provider block)

## Troubleshooting Quick Ref

| Error | Solution |
|-------|----------|
| `InvalidAction` for OIDC provider | Check URL, client ID, and thumbprint |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Verify trust policy conditions and CloudTrail logs |
| `Access Denied` when running | Check role has required permissions |
| Works locally, fails in cloud | Different credentials used - verify OIDC role permissions |

## Your Account Details

- **AWS Account ID**: Find in AWS Console (Account Settings)
- **Organization**: `Datafaced`
- **Workspace**: `management-foundation-iam-roles-for-people`
- **Region**: `ap-southeast-2`

## Documentation

For detailed steps, see: `/workspace/docs/how-to-guides/terraform-cloud-aws-authentication.md`

Also refer to:

- ADR-001: Terraform State Management
- ADR-010: AWS IAM Role Structure

## Next Actions

1. **Immediately**: Create OIDC provider and role in AWS
2. **Next**: Configure Terraform Cloud variable set
3. **Then**: Test with a small change push
4. **Finally**: Monitor CloudTrail and logs

## Support Resources

- [Terraform Cloud OIDC Documentation](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- CloudTrail logs in AWS Console
- Terraform Cloud workspace run logs
