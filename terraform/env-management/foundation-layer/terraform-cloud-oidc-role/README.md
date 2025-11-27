# Management Account - Foundation Layer - Terraform Cloud OIDC Role

This Terraform configuration creates the foundational AWS resources needed for Terraform Cloud to authenticate to AWS using OpenID Connect (OIDC).

## Overview

This configuration sets up:

1. **OIDC Provider** - AWS OIDC identity provider for Terraform Cloud
2. **IAM Role** - Role that Terraform Cloud assumes to manage infrastructure
3. **Inline Policy** - Permissions for IAM Identity Center management

## Architecture

This implements the OIDC authentication mechanism described in [TERRAFORM-CLOUD-AUTHENTICATION-REVIEW.md](../../../../docs/TERRAFORM-CLOUD-AUTHENTICATION-REVIEW.md):

```text
Terraform Cloud
    ↓ (OIDC token)
AWS OIDC Provider
    ↓ (validates token)
IAM Role (terraform-cloud-oidc-role)
    ↓ (grants temporary credentials)
Terraform Cloud
    ↓ (provisions resources)
AWS API
```

## Prerequisites

### 1. Terraform Cloud Setup

- Terraform Cloud account
- Organization created: `Datafaced`
- Workspace planned: `management-foundation-terraform-cloud-oidc-role`

### 2. AWS Setup

- AWS Management account access
- AWS CLI configured with credentials (can be SSO or IAM user)
- Admin-level or sufficient permissions to:
  - Create OIDC providers
  - Create IAM roles
  - Attach role policies

### 3. Terraform Cloud API Token (for first run)

You'll need a Terraform Cloud API token to authenticate from your local machine:

```bash
# Generate token at: https://app.terraform.io/app/settings/tokens
# Set it in your environment
export TF_TOKEN_app_terraform_io="YOUR_TOKEN_HERE"
```

## Setup Instructions

### Step 1: Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update these required values:

- `owner`: Your email address or team name
- Other values have sensible defaults for Datafaced organization

### Step 2: Create Terraform Cloud Workspace

Before running Terraform locally, create the workspace in Terraform Cloud:

1. Go to [https://app.terraform.io/app/Datafaced/workspaces](https://app.terraform.io/app/Datafaced/workspaces)
2. Click "New workspace"
3. Choose "API-driven workflow" (not VCS-driven for this bootstrap)
4. Name it: `management-foundation-terraform-cloud-oidc-role`
5. Click "Create workspace"

### Step 3: Set Terraform Cloud Token

```bash
# Option 1: Using environment variable
export TF_TOKEN_app_terraform_io="YOUR_TERRAFORM_CLOUD_API_TOKEN"

# Option 2: Using credentials file (permanent)
# Create ~/.terraform.d/credentials.tfrc.json
cat > ~/.terraform.d/credentials.tfrc.json <<EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "YOUR_TERRAFORM_CLOUD_API_TOKEN"
    }
  }
}
EOF

chmod 600 ~/.terraform.d/credentials.tfrc.json
```

To generate a token:

1. Go to [https://app.terraform.io/app/settings/tokens](https://app.terraform.io/app/settings/tokens)
2. Click "Create an API token"
3. Give it a description: "Terraform CLI - OIDC Setup"
4. Copy the token and save it securely

### Step 4: Configure AWS Credentials

Ensure your AWS credentials are configured for the management account:

```bash
# Option 1: Using AWS profile
export AWS_PROFILE=management  # Or your management account profile

# Option 2: Using environment variables
export AWS_ACCESS_KEY_ID="YOUR_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"

# Verify access
aws sts get-caller-identity
```

### Step 5: Initialize and Plan

```bash
# Navigate to the directory
cd /workspace/terraform/env-management/foundation-layer/terraform-cloud-oidc-role

# Initialize Terraform
terraform init

# Review the plan
terraform plan
```

You should see the plan will create:

- `aws_iam_openid_connect_provider.terraform_cloud` - OIDC Provider
- `aws_iam_role.terraform_cloud_oidc` - IAM Role
- `aws_iam_role_policy.terraform_cloud_oidc` - Inline Policy

### Step 6: Apply

```bash
# Apply the configuration
terraform apply

# Confirm by typing 'yes' when prompted
```

The apply will output:

- `terraform_cloud_oidc_provider_arn` - ARN of the OIDC provider
- `terraform_cloud_oidc_role_arn` - ARN of the OIDC role (needed for next step)
- `aws_account_id` - Your AWS account ID

### Step 7: Configure Terraform Cloud Workspace

Now that the OIDC role exists, configure your Terraform Cloud workspace to use it:

1. Go to workspace settings: [https://app.terraform.io/app/Datafaced/workspaces/management-foundation-terraform-cloud-oidc-role/settings/general](https://app.terraform.io/app/Datafaced/workspaces/management-foundation-terraform-cloud-oidc-role/settings/general)

2. Scroll to "Execution Mode" and change from "Agent" to "Remote"

3. Go to "Variables" tab and create these environment variables:

   ```bash
   TFC_AWS_PROVIDER_AUTH = "true"
   TFC_AWS_RUN_ROLE_ARN = "arn:aws:iam::ACCOUNT_ID:role/terraform-cloud-oidc-role"
   ```

   Replace `ACCOUNT_ID` with your actual AWS account ID (from the terraform apply output).

### Step 8: Migrate State to Terraform Cloud (Optional)

If you want to manage this configuration from Terraform Cloud VCS runs:

1. Create or connect a GitHub repository
2. Update workspace settings to use VCS
3. Push this code to GitHub
4. Terraform Cloud will automatically run plans on commits

## Output Values

After applying, save these values for configuring other workspaces:

```bash
# Get the role ARN
terraform output terraform_cloud_oidc_role_arn

# Get the account ID
terraform output aws_account_id
```

You'll need the role ARN when setting up other Terraform Cloud workspaces to use OIDC authentication.

## Permissions

The created role has permissions to manage:

- **IAM Identity Center** - Full access (`identitystore:*`, `sso:*`, `ssoadmin:*`)
- Future phases will create environment-specific roles with more granular permissions

## Security Considerations

1. **OIDC Thumbprint**: The Terraform Cloud OIDC thumbprint (9e99a48a9960b14926bb7f3b02e22da2b0ab7280) should be verified periodically against Terraform Cloud's published thumbprints

2. **Trust Policy**: The role trust policy restricts tokens to:
   - Terraform Cloud organization: `Datafaced`
   - Any project and workspace within the organization
   - Supports all run phases

3. **No Stored Credentials**: OIDC tokens are short-lived (expire after use), no API keys to rotate

4. **Audit Trail**: All role usage is logged in CloudTrail under `AssumeRoleWithWebIdentity` events

## Troubleshooting

### Terraform Cloud Cannot Authenticate

**Error**: `Access denied` or `Not authorized to assume role`

**Solution**:

- Verify the role ARN in workspace variables matches the created role
- Check the trust policy subject claim matches your organization name
- Ensure `TFC_AWS_PROVIDER_AUTH` is set to `"true"`
- Verify the OIDC provider thumbprint is current

### Permissions Denied During Apply

**Error**: `AccessDenied` on specific AWS API calls

**Solution**:

- The role needs appropriate permissions for your resources
- Update the inline policy to grant additional permissions
- Consider using environment-specific roles for different permissions per environment

### Terraform Cloud Token Expired

**Error**: `Error: error requesting remote operation: not authorized`

**Solution**:

- Generate a new Terraform Cloud API token
- Update your credentials file or environment variable

### AWS Credentials Not Found

**Error**: `Error: error configuring AWS Provider: no valid credential sources found`

**Solution**:

```bash
# Ensure AWS credentials are configured
aws sts get-caller-identity

# If using SSO
aws sso login --profile management

# Then set the profile
export AWS_PROFILE=management
```

## Next Steps

After this workspace is configured:

1. **Create environment-specific OIDC roles** for development, staging, and production
2. **Configure other Terraform Cloud workspaces** to use OIDC authentication
3. **Begin managing infrastructure** through Terraform Cloud VCS workflows

## References

- [Terraform Cloud OIDC Documentation](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [TERRAFORM-CLOUD-AUTHENTICATION-REVIEW.md](../../../../docs/TERRAFORM-CLOUD-AUTHENTICATION-REVIEW.md)
- [ADR-010: AWS IAM Role Structure](../../../../docs/reference/architecture-decision-register/ADR-010-aws-aim-role-structure.md)
