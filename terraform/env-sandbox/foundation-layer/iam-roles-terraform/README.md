# Sandbox Foundation Layer - IAM Roles

## Overview

This directory contains Terraform configuration for IAM roles and permission sets in the Sandbox environment.

## What's Deployed

### OIDC-Based IAM Roles

#### Foundation Layer

- **CICD Role**: `terraform-sandbox-foundation-cicd-role`
  - For automated CI/CD pipelines
  - Subject: `repo:org/repo:ref:refs/heads/main`
  - Session: 2 hours
  - Permissions: VPC, networking, DNS, KMS

- **Human Role**: `terraform-sandbox-foundation-human-role`
  - For human operators (via GitHub)
  - Subject pattern: `repo:org/repo:*`
  - Session: 12 hours (generous for sandbox work)
  - Permissions: Same as CICD role

#### Platform Layer

- **CICD Role**: `terraform-sandbox-platform-cicd-role`
  - Permissions: EKS, RDS, ELB, Secrets Manager, SSM

- **Human Role**: `terraform-sandbox-platform-human-role`
  - Permissions: Same as CICD role

#### Application Layer

- **CICD Role**: `terraform-sandbox-application-cicd-role`
  - Permissions: Lambda, S3, DynamoDB, API Gateway, SQS, SNS

- **Human Role**: `terraform-sandbox-application-human-role`
  - Permissions: Same as CICD role

#### Experiments Layer (Sandbox-Specific)

- **Human Role**: `terraform-sandbox-experiments-human-role`
  - Broad permissions for experimentation
  - PowerUser + additional services
  - Safeguards: Cannot modify account/org settings
  - Session: 12 hours

### IAM Identity Center Permission Sets

#### Foundation Permission Set

- **Name**: `SandboxFoundationAdmin`
- **Description**: Sandbox Foundation layer administrative access
- **Session**: 12 hours
- **Permissions**: VPC, networking, Route53, KMS + ReadOnly

#### Platform Permission Set

- **Name**: `SandboxPlatformAdmin`
- **Description**: Sandbox Platform layer administrative access
- **Session**: 12 hours
- **Permissions**: EKS, RDS, ELB, Secrets + ReadOnly

#### Application Permission Set

- **Name**: `SandboxApplicationAdmin`
- **Description**: Sandbox Application layer administrative access
- **Session**: 12 hours
- **Permissions**: Lambda, S3, DynamoDB, API Gateway + ReadOnly

#### Experiments Permission Set

- **Name**: `SandboxExperimentsAdmin`
- **Description**: Broad access for experimentation
- **Session**: 12 hours
- **Permissions**: PowerUser access + safeguards

## Prerequisites

### 1. OIDC Provider in Sandbox Account

Create GitHub OIDC provider in Sandbox AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. IAM Identity Center

- Sandbox account added to organization
- IAM Identity Center enabled
- Groups created for sandbox access

### 3. Terraform Cloud Workspace

Create workspace: `sandbox-foundation-iam-roles`

- Organization: `Datafaced`
- VCS Connection: This repository
- Working Directory: `terraform/env-sandbox/foundation-layer/iam-roles-terraform/`
- Auto-apply: Enabled (for sandbox)

## Configuration

### 1. Copy and Edit terraform.tfvars

```bash
cd terraform/env-sandbox/foundation-layer/iam-roles-terraform/
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update Values

```hcl
# Sandbox AWS Account ID
oidc_provider_arn = "arn:aws:iam::SANDBOX_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"

# GitHub Configuration
github_org  = "your-org"
github_repo = "terraform"

# Permission Set Account Assignments
foundation_account_assignments = {
  sandbox_team = {
    principal_id   = "GROUP_ID_FROM_IAM_IDENTITY_CENTER"
    principal_type = "GROUP"
    account_id     = "SANDBOX_ACCOUNT_ID"
  }
}

# Repeat for platform, application, and experiments
```

### 3. Deploy

```bash
# Commit and push - Terraform Cloud will apply
git add .
git commit -m "feat: configure sandbox IAM roles"
git push
```

## Usage

### Using OIDC Roles in GitHub Actions

```yaml
name: Deploy to Sandbox

on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials (Foundation Layer)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::SANDBOX_ACCOUNT_ID:role/terraform-sandbox-foundation-human-role
          aws-region: us-east-1
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Apply
        run: terraform apply -auto-approve
```

### Using Permission Sets (Human Access)

1. Go to AWS Access Portal
2. Select Sandbox account
3. Choose appropriate permission set:
   - `SandboxFoundationAdmin` for networking/VPC work
   - `SandboxPlatformAdmin` for EKS/RDS work
   - `SandboxApplicationAdmin` for Lambda/S3 work
   - `SandboxExperimentsAdmin` for broad experimentation
4. Access via AWS Console or CLI

### CLI Access via Permission Set

```bash
# Get temporary credentials
aws sso login --profile sandbox

# Use with AWS CLI
aws s3 ls --profile sandbox

# Or export credentials
eval $(aws configure export-credentials --profile sandbox --format env)
```

## Security Considerations

### Broader Permissions

Sandbox has more permissive roles than other environments:

- ✅ **Appropriate for**: Learning, testing, experimentation
- ⚠️ **Not appropriate for**: Production data, long-lived resources
- 🛡️ **Safeguards**: Cannot modify account/org settings, tagged for audit

### Session Durations

- **CICD Roles**: 2 hours (standard)
- **Human Roles**: 12 hours (generous for sandbox work)
- **Experiments**: 12 hours (for extended testing sessions)

### Permission Boundaries

Optional: Apply permission boundary to limit maximum permissions:

```hcl
permission_boundary_arn = "arn:aws:iam::SANDBOX_ACCOUNT_ID:policy/SandboxMaxPermissions"
```

## Outputs

After deployment, the following outputs are available:

```hcl
# OIDC Role ARNs
foundation_cicd_role_arn
foundation_human_role_arn
platform_cicd_role_arn
platform_human_role_arn
application_cicd_role_arn
application_human_role_arn
experiments_human_role_arn

# Permission Set ARNs
foundation_permission_set_arn
platform_permission_set_arn
application_permission_set_arn
experiments_permission_set_arn
```

Use these ARNs in other configurations or CI/CD pipelines.

## Maintenance

### Regular Reviews

- Monthly: Review permission sets and roles
- Quarterly: Audit usage logs
- As needed: Adjust permissions based on use cases

### Adding New Roles

To add new layer-specific roles:

1. Add module block in `main.tf`
2. Define permissions inline or reference policy
3. Add outputs in `outputs.tf`
4. Deploy via Terraform Cloud

### Removing Roles

To remove deprecated roles:

1. Remove module block from `main.tf`
2. Remove outputs from `outputs.tf`
3. Verify nothing depends on the role
4. Deploy via Terraform Cloud (will destroy role)

## Troubleshooting

### Issue: OIDC Trust Relationship Failed

**Symptoms**: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Solutions**:

1. Verify OIDC provider exists in Sandbox account
2. Check GitHub repository matches configuration
3. Verify subject claim pattern is correct
4. Check token audience matches `sts.amazonaws.com`

### Issue: Permission Denied

**Symptoms**: "User: arn:aws:sts::ACCOUNT:assumed-role/ROLE is not authorized"

**Solutions**:

1. Check which role you're using (foundation vs platform vs application)
2. Verify permission boundary isn't blocking action
3. Check if resource policy denies access
4. Verify service quota isn't exceeded

### Issue: Permission Set Not Showing Up

**Symptoms**: Permission set not visible in AWS Access Portal

**Solutions**:

1. Verify account assignment is correct
2. Check principal_id (group ID) is valid
3. Verify account_id matches Sandbox account
4. Allow 5-10 minutes for IAM Identity Center propagation

## Related Documentation

- [Sandbox Environment README](../../README.md)
- [ADR-010: AWS IAM Role Structure](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
- [IAM Identity Center Setup](../../../../docs/explanations/aws-iam-identity-center.md)

## Support

Questions about Sandbox IAM roles?

1. Check this README
2. Review ADR-010
3. Check Terraform module: `terraform-modules/terraform-oidc-role/`
4. Ask in team Slack channel
