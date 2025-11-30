# GitHub Actions Workflows

This directory contains GitHub Actions workflows for Terraform infrastructure provisioning.

## Workflows

| Workflow | File | Description |
|----------|------|-------------|
| Dev Platform EKS | `terraform-dev-platform-eks.yml` | Provisions EKS Auto Mode cluster in development |
| EKS TTL Check | `eks-ttl-check.yml` | Hourly check for expired clusters (auto-destroy) |

## Cost Protection: TTL-Based Auto-Destroy

To prevent forgotten EKS clusters from running up unexpected AWS costs, all clusters are tagged with a Time-To-Live (TTL) value. A separate workflow (`eks-ttl-check.yml`) runs hourly to check for expired clusters and automatically destroys them.

### How It Works

1. **On cluster creation:** The cluster is tagged with:
   - `TTL_Hours`: How long the cluster should live (default: 8 hours)
   - `CreatedAt`: ISO 8601 timestamp of creation
   - `DestroyBy`: ISO 8601 timestamp when cluster should be destroyed

2. **Hourly check:** The TTL check workflow runs every hour and:
   - Lists all EKS clusters in each environment
   - Checks the `DestroyBy` tag against current time
   - Destroys any clusters that have exceeded their TTL

3. **Manual override:** You can:
   - Set `ttl_hours=0` when creating to disable auto-destroy
   - Manually destroy earlier via workflow dispatch
   - Run TTL check in dry-run mode to preview what would be destroyed

### TTL Configuration

| TTL Value | Behaviour |
|-----------|-----------|
| `8` (default) | Cluster auto-destroys after 8 hours |
| `0` | No auto-destroy (manual destroy only) |
| Any number | Cluster auto-destroys after that many hours |

### Example Usage

```bash
# Create cluster with default 8-hour TTL
gh workflow run terraform-dev-platform-eks.yml -f action=apply

# Create cluster with 4-hour TTL (short learning session)
gh workflow run terraform-dev-platform-eks.yml -f action=apply -f ttl_hours=4

# Create cluster with no TTL (remember to destroy manually!)
gh workflow run terraform-dev-platform-eks.yml -f action=apply -f ttl_hours=0

# Check what would be destroyed (dry run)
gh workflow run eks-ttl-check.yml -f dry_run=true

# Force destroy all expired clusters now
gh workflow run eks-ttl-check.yml -f dry_run=false
```

## Authentication

All workflows use OIDC federation with AWS IAM for secure, short-lived credentials. See [ADR-013](../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md) for details.

## Required Secrets

Configure these secrets in your GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ROLE_ARN_DEV_PLATFORM` | ARN of the IAM role for dev platform | `arn:aws:iam::123456789012:role/github-actions-dev-platform` |
| `TF_API_TOKEN` | Terraform Cloud API token | `<your-token>` |

### Getting the AWS Role ARN

After applying the OIDC role Terraform:

```bash
cd terraform/env-management/foundation-layer/github-actions-oidc-role
terraform output github_actions_dev_platform_role_arn
```

### Getting the Terraform Cloud Token

#### Option 1: User Token (Free Tier)

If you're on the **Terraform Cloud Free tier**, use a User Token:

1. Go to [Terraform Cloud](https://app.terraform.io)
2. Click your avatar → **User Settings** → **Tokens**
3. Click **Create an API token**
4. Give it a description (e.g., "GitHub Actions")
5. Copy the token and add as `TF_API_TOKEN` secret in GitHub

> ⚠️ **Note**: User tokens are tied to your account. If you leave the organization, the CI/CD pipeline will break.

#### Option 2: Team Token (Paid Tiers)

If you're on a **paid Terraform Cloud plan** (Team & Governance, Business, etc.), use a Team Token:

1. Go to [Terraform Cloud](https://app.terraform.io)
2. Navigate to your organization → **Settings** → **Teams**
3. Create a team (e.g., `github-actions`)
4. Assign the team to workspace `development-platform-eks` with **Apply** permissions
5. Go to **Team API Token** → **Create a team token**
6. Add it as `TF_API_TOKEN` secret in GitHub

#### Token Type Comparison

| Token Type | TFC Tier | Best For | Pros | Cons |
|------------|----------|----------|------|------|
| User Token | Free ✅ | Getting started | Easy to create | Tied to individual |
| **Team Token** | Paid | CI/CD pipelines | Not tied to a person | Requires paid plan |
| Organization Token | Paid | Admin automation | Org-wide access | Too broad for CI/CD |

## Required Environments

Create these environments in GitHub repository settings (**Settings** → **Environments**):

| Environment | Purpose | Protection Rules |
|-------------|---------|------------------|
| `development` | EKS apply approval | Optional: require reviewers |
| `development-destroy` | EKS destroy approval | **Required**: require reviewers |

### Recommended Protection Rules

For `development`:

- Optional reviewers (for awareness)
- Restrict to `main` branch

For `development-destroy`:

- **Required reviewers** (at least 1)
- Restrict to `main` branch
- Add deployment delay (e.g., 5 minutes)

## Workflow Triggers

### Automatic Triggers

| Event | Action |
|-------|--------|
| Push to `main` (matching paths) | Plan + Apply |
| Pull Request (matching paths) | Plan only + PR comment |
| Hourly (TTL check) | Check and destroy expired clusters |

### Manual Triggers

Use **Actions** → **Terraform: Dev Platform EKS** → **Run workflow**:

| Input | Description |
|-------|-------------|
| `plan` | Run plan only |
| `apply` | Run plan + apply |
| `destroy` | Destroy all resources |
| `ttl_hours` | Time-to-live in hours (default: 8, 0 = no auto-destroy) |

## Directory Structure

```text
.github/
├── copilot-instructions.md    # AI assistant guidelines
├── workflows/
│   ├── README.md              # This file
│   ├── terraform-dev-platform-eks.yml
│   └── eks-ttl-check.yml      # TTL-based auto-destroy
```

## Extending for Other Environments

To add staging/production workflows:

1. Create new IAM roles (e.g., `github-actions-staging-platform`)
2. Add corresponding secrets (e.g., `AWS_ROLE_ARN_STAGING_PLATFORM`)
3. Copy and modify the workflow file
4. Create new environments with appropriate protection rules

## Troubleshooting

### OIDC Authentication Fails

1. Verify the IAM role trust policy allows your repository
2. Check the subject condition matches: `repo:dr3dr3/terraform:*`
3. Ensure `id-token: write` permission is set in workflow

### Terraform Cloud Authentication Fails

1. Verify `TF_API_TOKEN` secret is set
2. Check token has access to the workspace
3. Ensure workspace exists: `development-platform-eks`

### Plan Succeeds but Apply Fails

1. Check IAM role has sufficient permissions
2. Review CloudTrail logs for denied actions
3. Update the IAM policy in `github-actions-oidc-role`
