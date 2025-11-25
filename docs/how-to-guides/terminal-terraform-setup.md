# Running Terraform from Your Terminal

## Quick Start

You can now run Terraform directly from your terminal using your AWS SSO credentials!

### Prerequisites ✅

- [x] AWS CLI configured with SSO profile `Admin-Dev`
- [x] SSO authentication working (`aws sso login --profile Admin-Dev`)
- [x] Terraform installed

### Daily Workflow

#### 1. Authenticate with AWS SSO (once per session)

```fish
aws sso login --profile Admin-Dev
```

This logs you into AWS and your session will last 8-12 hours.

#### 2. Set your AWS profile for Terraform

```fish
# In fish shell
set -x AWS_PROFILE Admin-Dev

# Or for a single command
env AWS_PROFILE=Admin-Dev terraform plan
```

#### 3. Run Terraform commands

```fish
cd /workspace/terraform/env-development/applications-layer/eks-learning-cluster

# Initialize (first time or after changes)
terraform init

# See what would be created/changed
terraform plan

# Apply changes
terraform apply
```

## How It Works

Your current setup:

1. **AWS SSO Profile (`Admin-Dev`)**: Provides AdministratorAccess to your AWS account
2. **Terraform AWS Provider**: Automatically uses credentials from the `AWS_PROFILE` environment variable
3. **No OIDC roles needed**: For terminal use, you don't need the OIDC roles - those are for CI/CD pipelines

## About OIDC Roles (From ADR-010)

The ADR describes **two types of access**:

### 1. Human Terminal Access (What you're using now)

- Uses AWS SSO directly via `Admin-Dev` profile
- No OIDC roles required
- Best for development and testing

### 2. CI/CD Pipeline Access (Not set up yet)

- Uses OIDC roles like `terraform-development-foundation-cicd-role`
- Requires GitHub Actions OIDC provider configured
- Enables GitHub Actions to deploy infrastructure automatically

**You already have #1 working!** The OIDC roles in ADR-010 are for future CI/CD setup.

## Backend Configuration

Currently using **local state** (terraform.tfstate file) for simplicity. The code has placeholders for Terraform Cloud which you can enable later.

To switch to Terraform Cloud:

1. Create workspace in Terraform Cloud organization "Datafaced"
2. Uncomment the `cloud` block in your Terraform configuration
3. Run `terraform init -migrate-state`

## Verify Setup

Test your authentication:

```fish
# Check AWS credentials
env AWS_PROFILE=Admin-Dev aws sts get-caller-identity

# Should show your AWS account details
```

## Troubleshooting

**Session expired error?**

```fish
aws sso login --profile Admin-Dev
```

**Terraform can't find credentials?**

```fish
# Make sure AWS_PROFILE is set
echo $AWS_PROFILE

# If not set:
set -x AWS_PROFILE Admin-Dev
```

**Want to switch environments?**

When you have multiple environments (dev, staging, prod), just switch profiles:

```fish
set -x AWS_PROFILE Admin-Staging  # When that exists
```

## Summary

✅ **You can now run Terraform from your terminal!**

The setup is:

- `aws sso login --profile Admin-Dev` (authenticate)
- `set -x AWS_PROFILE Admin-Dev` (set profile)
- `terraform plan/apply` (run Terraform)

No OIDC roles needed for terminal use - those are only for automated CI/CD pipelines!
