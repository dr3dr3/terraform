# EKS Admin Devcontainer - AWS SSO Setup Guide

This guide explains how to set up AWS SSO (IAM Identity Center) in the EKS admin devcontainer to access your EKS clusters. This follows the approach defined in [ADR-016](../reference/architecture-decision-register/ADR-016-eks-credentials-cross-repo-access.md).

## Overview

The EKS admin devcontainer uses AWS SSO for authentication instead of storing long-lived credentials. This provides:

- **Short-lived tokens**: Automatically rotated, reducing security risk
- **Centralized identity**: Uses existing IAM Identity Center users/groups
- **Audit trail**: All access logged in CloudTrail
- **Multi-cluster support**: Single login grants access to all environments

## Prerequisites

Before starting, ensure:

- [ ] Access to the EKS admin devcontainer repository
- [ ] Your IAM Identity Center user account has been created
- [ ] You've been assigned to the appropriate group(s) - see User Personas
- [ ] The devcontainer has AWS CLI v2 and kubectl installed

## User Personas and Permissions

The following permission sets are available via IAM Identity Center. Your access depends on which group(s) you belong to:

| Persona | Permission Set | AWS Access | K8s Role | Accounts |
|---------|---------------|------------|----------|----------|
| **Administrator** | `AdministratorAccess` | Full AWS access | `cluster-admin` | All |
| **Platform Engineer** | `PlatformEngineerAccess` | EKS, VPC, ECR management | `cluster-admin` | All |
| **Namespace Admin** | `NamespaceAdminAccess` | EKS describe, ECR push/pull | `namespace-admin` | Non-prod only |
| **Developer** | `DeveloperAccess` | EKS describe, ECR, CloudWatch | `developer` | Non-prod only |
| **Auditor** | `AuditorAccess` | Read-only | `view` | All |

## Step 1: Start the Devcontainer

Open the EKS admin repository in VS Code and start the devcontainer:

```bash
# Clone the repository (if not already done)
git clone git@github.com:dr3dr3/eks-admin.git
cd eks-admin

# Open in VS Code and start devcontainer
code .
# Then: Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
```

## Step 2: Configure AWS SSO

### 2.1 Run the SSO Configuration Wizard

Inside the devcontainer, run:

```bash
aws configure sso
```

You'll be prompted for the following values:

| Prompt | Value |
|--------|-------|
| **SSO session name** | `datafaced` |
| **SSO start URL** | `https://d-9a67083b1a.awsapps.com/start` |
| **SSO region** | `ap-southeast-2` |
| **SSO registration scopes** | Press Enter (accept default) |

### 2.2 Authenticate in Browser

The CLI will open a browser window (or display a URL to open manually). Log in with your IAM Identity Center credentials.

### 2.3 Select Account and Role

After authentication, select the account and permission set:

```text
There are 5 AWS accounts available to you.
> 126350206316 (Development)
  163436765579 (Staging)
  820485071161 (Production)
  898468025925 (Sandbox)
  169506999567 (Management)
```

Select the account you want to configure first (e.g., Development), then choose your permission set:

```text
Using the account ID 126350206316
There are 3 roles available to you.
> AdministratorAccess
  PlatformEngineerAccess
  DeveloperAccess
```

### 2.4 Complete the Profile Configuration

```text
CLI default client Region [None]: ap-southeast-2
CLI default output format [None]: json
CLI profile name [AdministratorAccess-126350206316]: dev-admin
```

Use descriptive profile names like `dev-admin`, `dev-platform`, `sandbox-dev`, etc.

### 2.5 Repeat for Additional Accounts/Roles

Configure profiles for each account/role combination you need:

```bash
# Development with Administrator access
aws configure sso
# Profile name: dev-admin

# Development with Platform Engineer access
aws configure sso
# Profile name: dev-platform

# Sandbox with Developer access
aws configure sso
# Profile name: sandbox-dev
```

**Important:** Use the same SSO session name (`datafaced`) for all profiles. This allows a single login to authenticate all profiles.

## Step 3: Verify Your Configuration

Check your AWS config file:

```bash
cat ~/.aws/config
```

It should look like:

```ini
[sso-session datafaced]
sso_start_url = https://d-9a67083b1a.awsapps.com/start
sso_region = ap-southeast-2
sso_registration_scopes = sso:account:access

[profile dev-admin]
sso_session = datafaced
sso_account_id = 126350206316
sso_role_name = AdministratorAccess
region = ap-southeast-2
output = json

[profile dev-platform]
sso_session = datafaced
sso_account_id = 126350206316
sso_role_name = PlatformEngineerAccess
region = ap-southeast-2
output = json

[profile sandbox-dev]
sso_session = datafaced
sso_account_id = 898468025925
sso_role_name = DeveloperAccess
region = ap-southeast-2
output = json
```

## Step 4: Log In to AWS SSO

Authenticate with a single command:

```bash
aws sso login --sso-session datafaced
```

This authenticates you to ALL configured profiles at once.

Verify your session:

```bash
aws sts get-caller-identity --profile dev-admin
```

Expected output:

```json
{
    "UserId": "AROAXXXXXXXXX:andre.dreyer@datafaced.com",
    "Account": "126350206316",
    "Arn": "arn:aws:sts::126350206316:assumed-role/AWSReservedSSO_AdministratorAccess_xxxxxxxxx/andre.dreyer@datafaced.com"
}
```

## Step 5: Configure kubectl for EKS

### Option A: Using 1Password (Recommended)

If your devcontainer has access to 1Password, use the setup script:

```bash
# Set 1Password service account token (if not already set)
set -gx OP_SERVICE_ACCOUNT_TOKEN "your-token-here"

# Run the setup script to configure all EKS clusters
./scripts/setup-kubeconfig.fish
```

### Option B: Manual Configuration

Update your kubeconfig manually for each cluster:

```bash
# Set the profile to use
set -gx AWS_PROFILE dev-admin

# Update kubeconfig for the development EKS cluster
aws eks update-kubeconfig \
    --region ap-southeast-2 \
    --name dev-eks-auto-mode \
    --alias dev-eks
```

Verify the connection:

```bash
kubectl get nodes
```

Expected output:

```text
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ap-southeast-2.compute.internal Ready    <none>   7d    v1.31.x
```

## Step 6: Daily Workflow

### Starting Your Day

```bash
# 1. Log in to AWS SSO (sessions last 8-12 hours)
aws sso login --sso-session datafaced

# 2. Set your working profile
set -gx AWS_PROFILE dev-admin

# 3. Verify cluster access
kubectl get nodes
```

### Switching Between Clusters/Accounts

```bash
# List available kubectl contexts
kubectl config get-contexts

# Switch context
kubectl config use-context dev-eks

# Or use kubectx (if installed via krew)
kubectl ctx dev-eks

# Switch AWS profile for a different account
set -gx AWS_PROFILE sandbox-dev
```

### When Your Session Expires

If you see authentication errors, simply re-login:

```bash
aws sso login --sso-session datafaced
```

## Recommended Profile Configuration

For a complete setup, configure these profiles:

### Development Account (126350206316)

| Profile Name | Role | Use Case |
|--------------|------|----------|
| `dev-admin` | AdministratorAccess | Full admin access |
| `dev-platform` | PlatformEngineerAccess | EKS/infrastructure work |
| `dev-dev` | DeveloperAccess | Application deployment |

### Sandbox Account (898468025925)

| Profile Name | Role | Use Case |
|--------------|------|----------|
| `sandbox-admin` | AdministratorAccess | Testing/experiments |
| `sandbox-platform` | PlatformEngineerAccess | Platform testing |
| `sandbox-dev` | DeveloperAccess | Developer testing |

### Staging Account (163436765579)

| Profile Name | Role | Use Case |
|--------------|------|----------|
| `staging-admin` | AdministratorAccess | Pre-production admin |
| `staging-platform` | PlatformEngineerAccess | Platform deployment |

### Production Account (820485071161)

| Profile Name | Role | Use Case |
|--------------|------|----------|
| `prod-admin` | AdministratorAccess | Production admin (break-glass) |
| `prod-platform` | PlatformEngineerAccess | Production changes |
| `prod-audit` | AuditorAccess | Compliance review |

## Quick Reference: Fish Shell Commands

```bash
# Set AWS profile for current session
set -gx AWS_PROFILE dev-admin

# List configured profiles
aws configure list-profiles

# Login to SSO
aws sso login --sso-session datafaced

# Check current identity
aws sts get-caller-identity

# Update kubeconfig for EKS cluster
aws eks update-kubeconfig --region ap-southeast-2 --name dev-eks-auto-mode --alias dev-eks

# List kubectl contexts
kubectl config get-contexts

# Switch kubectl context
kubectl config use-context dev-eks

# Test cluster access
kubectl get nodes
kubectl get pods -A
```

## Troubleshooting

### "Error loading SSO Token"

Your session has expired. Re-authenticate:

```bash
aws sso login --sso-session datafaced
```

### "Unable to locate credentials"

Set the AWS_PROFILE environment variable:

```bash
set -gx AWS_PROFILE dev-admin
```

### "You must be logged in to the server (Unauthorized)"

Your AWS session expired or the wrong profile is set:

```bash
# Check current profile
echo $AWS_PROFILE

# Re-login
aws sso login --sso-session datafaced

# Refresh kubeconfig
aws eks update-kubeconfig --region ap-southeast-2 --name dev-eks-auto-mode
```

### "The config profile could not be found"

The profile name doesn't exist in `~/.aws/config`. List available profiles:

```bash
aws configure list-profiles
```

### Clear Cached Credentials

If you're having persistent issues:

```bash
rm -rf ~/.aws/sso/cache/
rm -rf ~/.aws/cli/cache/
rm ~/.kube/config  # Warning: removes all kubectl contexts

# Reconfigure
aws sso login --sso-session datafaced
aws eks update-kubeconfig --region ap-southeast-2 --name dev-eks-auto-mode --alias dev-eks
```

## Security Notes

1. **Never commit credentials**: AWS config files should not contain access keys
2. **Use appropriate roles**: Choose the minimum permission level needed for your task
3. **Session duration**: SSO sessions are time-limited (8-12 hours depending on permission set)
4. **Audit trail**: All API calls are logged in CloudTrail under your identity

## Related Documentation

- [ADR-016: EKS Credentials and Cross-Repository Access](../reference/architecture-decision-register/ADR-016-eks-credentials-cross-repo-access.md)
- [AWS CLI SSO Usage](./aws-cli-sso-usage.md)
- [1Password with Terraform](./1password-with-terraform.md)
- [AWS Accounts Reference](../reference/aws-accounts.md)
