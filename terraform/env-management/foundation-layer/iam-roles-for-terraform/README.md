# Management Account - Foundation Layer - IAM Roles for Terraform

This workspace creates IAM roles and OIDC provider configuration to enable Terraform Cloud to manage infrastructure across development, staging, and production environments using dynamic credentials.

## Overview

This configuration sets up:

1. **OIDC Provider** - Terraform Cloud identity provider in AWS
2. **IAM Roles** - Environment-specific roles for Terraform Cloud workspaces
3. **Policies** - Graduated permissions based on environment criticality

## Architecture

Following [ADR-010](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md), this implements Phase 2 (execution context split):

- **CICD Roles**: For Terraform Cloud workspace execution
- **Environment Separation**: Dev, Staging, Production with different permission levels

## Prerequisites

### 1. Terraform Cloud Setup

- Terraform Cloud account
- Organization created
- Projects created (optional but recommended):
  - `development`
  - `staging`
  - `production`

### 2. AWS Setup

- AWS Management account access
- AWS CLI configured with SSO (see [AWS CLI SSO Usage Guide](../../../../docs/how-to-guides/aws-cli-sso-usage.md))
- Admin-level permissions in Management account

### 3. Initial Bootstrap

Since this is creating the OIDC provider and roles, you need to run this **once** with local execution using your AWS credentials.

## Setup Instructions

### Step 1: Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update these required values:

- `tfc_organization`: Your Terraform Cloud organization name
- `owner`: Your email address
- `tfc_workspace_*`: Names of your Terraform Cloud workspaces

### Step 2: Update Backend Configuration

Edit `backend.tf` and replace `YOUR_TFC_ORG_NAME` with your actual Terraform Cloud organization.

### Step 3: Initial Local Apply (Bootstrap)

Since the OIDC provider doesn't exist yet, do the first apply locally:

```bash
# Authenticate to AWS Management account
aws sso login --profile management  # or your management account profile

# Set the profile
export AWS_PROFILE=management

# Initialize Terraform (but don't use cloud backend yet)
# Comment out the cloud block in backend.tf temporarily
terraform init

# Review the plan
terraform plan

# Apply to create OIDC provider and roles
terraform apply
```

### Step 4: Configure Terraform Cloud Workspace

Once the OIDC provider and roles are created:

1. **Create the workspace** in Terraform Cloud:
   - Name: `management-foundation-iam-roles-terraform`
   - Project: Choose appropriate project
   - Version Control: Connect to your repo (optional)

2. **Configure Dynamic Credentials**:
   - Go to workspace settings → Authentication
   - Enable "Dynamic Provider Credentials"
   - Select AWS
   - Add the role ARN (you'll get this from the terraform apply output or manually from AWS Console)

3. **Set Workspace Variables**:
   - `TFC_AWS_PROVIDER_AUTH` = `true`
   - `TFC_AWS_RUN_ROLE_ARN` = `arn:aws:iam::ACCOUNT_ID:role/terraform-management-foundation-cicd-role`

### Step 5: Migrate to Terraform Cloud

```bash
# Uncomment the cloud block in backend.tf
nano backend.tf

# Re-initialize to migrate state to Terraform Cloud
terraform init

# When prompted, type 'yes' to copy state to cloud
```

### Step 6: Verify

```bash
# In Terraform Cloud, queue a plan run
# It should authenticate using OIDC and show no changes
```

## Role ARNs Reference

After applying, note these role ARNs for configuring other workspaces:

- **Dev Foundation**: `arn:aws:iam::ACCOUNT_ID:role/terraform-dev-foundation-cicd-role`
- **Staging Foundation**: `arn:aws:iam::ACCOUNT_ID:role/terraform-staging-foundation-cicd-role`
- **Production Foundation**: `arn:aws:iam::ACCOUNT_ID:role/terraform-production-foundation-cicd-role`

## Configuring Other Workspaces

When creating Terraform Cloud workspaces for dev, staging, or production:

1. Enable Dynamic Provider Credentials
2. Use the appropriate role ARN from above
3. Set environment variables:

```bash
TFC_AWS_PROVIDER_AUTH=true
TFC_AWS_RUN_ROLE_ARN=<role-arn-for-environment>
```

## Permission Levels

### Development

- Full IAM management for terraform-* resources
- OIDC provider full management
- State management permissions
- Session duration: 2 hours

### Staging

- IAM role and policy management for terraform-* resources
- OIDC provider read-only access
- Session duration: 1 hour

### Production

- IAM read access with limited update permissions
- OIDC provider read-only access
- Region-restricted modifications
- Session duration: 1 hour

## Security Considerations

1. **OIDC Thumbprint**: The Terraform Cloud thumbprint in `main.tf` should be verified periodically
2. **Session Duration**: Production roles have shorter sessions to limit exposure
3. **Permission Boundaries**: Consider adding permission boundaries for additional safety
4. **CloudTrail**: Ensure CloudTrail is enabled to audit all role usage
5. **Alerts**: Set up CloudWatch alarms for unexpected role usage

## Troubleshooting

### OIDC Authentication Fails

Check:

- Role ARN in workspace matches output
- Trust policy subject claim matches workspace/organization pattern
- OIDC provider thumbprint is current

### Permission Denied

- Verify the role has necessary permissions for the operation
- Check if permission boundary is blocking the action
- Review CloudTrail for specific denied action

### State Migration Issues

```bash
# If migration fails, you can pull state locally
terraform state pull > terraform.tfstate

# Then manually upload to Terraform Cloud
```

## Next Steps

After this workspace is configured:

1. Create Terraform Cloud workspaces for each environment
2. Configure dynamic credentials in each workspace
3. Begin deploying environment-specific infrastructure

## References

- [ADR-010: AWS IAM Role Structure](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
- [AWS CLI SSO Usage Guide](../../../../docs/how-to-guides/aws-cli-sso-usage.md)
- [Terraform Cloud Dynamic Credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws)
