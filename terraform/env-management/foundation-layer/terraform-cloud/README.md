# Terraform Cloud Management with Terraform

This directory contains Terraform configuration to manage Terraform Cloud infrastructure as code. This is a "meta-Terraform" setup that creates and configures Terraform Cloud projects, workspaces, and settings.

## Overview

This configuration manages:

- **Projects**: Organizational containers for grouping related workspaces
- **Workspaces**: Individual Terraform state management units with VCS integration
- **VCS Integration**: GitHub repository connection for automated runs
- **Workspace Settings**: Auto-apply, Terraform version, working directories

## Architecture

### Projects Structure

Based on [ADR-009: Folder Structure](/workspace/docs/reference/architecture-decision-register/ADR-009-folder-structure.md), we organize workspaces into projects:

| Project | Purpose | Workspaces |
|---------|---------|------------|
| `aws-management` | Management account resources | IAM Identity Center, IAM roles, Terraform Cloud config |
| `aws-development` | Development environment | Foundation layer, applications, EKS clusters |
| `aws-sandbox` | Experimental resources | Testing, learning, experiments |
| `local-development` | LocalStack resources | Local development with no AWS costs |

### Workspace Naming Convention

Format: `{environment}-{layer}-{stack-name}`

Examples:

- `management-foundation-iam-roles-for-people`
- `development-applications-eks-learning-cluster`
- `sandbox-foundation-iam-roles-terraform`

## Prerequisites

### 1. Terraform Cloud Organization

- Organization name: `Datafaced`
- Created at: <https://app.terraform.io>

### 2. GitHub OAuth Connection

You need to connect GitHub to Terraform Cloud to enable VCS-driven workflows:

1. Log into Terraform Cloud: <https://app.terraform.io>
2. Navigate to: **Settings** → **Version Control** → **Providers**
3. Click **Add VCS Provider** → **GitHub** → **GitHub.com**
4. Authorize Terraform Cloud to access your GitHub organization
5. After authorization, you'll see an **OAuth Token ID** (format: `ot-xxxxxxxxxxxxx`)
6. Copy this OAuth Token ID for use in `terraform.tfvars`

### 3. Terraform Cloud API Token

Create an organization or user token for Terraform to authenticate:

#### Option A: Organization Token (Recommended)

1. Go to: **Settings** → **Teams & Governance** → **API Tokens**
2. Click **Create an organization token**
3. Description: "Terraform Cloud Management"
4. Copy the token (shown only once)

#### Option B: User Token

1. Click your profile icon → **User Settings** → **Tokens**
2. Click **Create an API token**
3. Description: "Terraform Cloud Management"
4. Copy the token (shown only once)

#### Set Token as Environment Variable

```bash
# Add to your shell profile (~/.config/fish/config.fish for fish shell)
set -gx TFE_TOKEN "your-token-here"

# Or create ~/.terraform.d/credentials.tfrc.json
printf '{\n  "credentials": {\n    "app.terraform.io": {\n      "token": "%s"\n    }\n  }\n}' "your-token-here" > ~/.terraform.d/credentials.tfrc.json
```

### 4. Create the Meta-Terraform Workspace

Before running this Terraform, you need to create the workspace it uses as its backend:

1. In Terraform Cloud, go to **Projects** → **Create Project**
   - Name: `aws-management`

2. Click **New Workspace** → **CLI-driven workflow**
   - Workspace name: `management-foundation-terraform-cloud`
   - Project: `aws-management`
   - Description: "Manages Terraform Cloud projects and workspaces"

3. This workspace will be managed by the Terraform code after first apply

## Setup Instructions

### Step 1: Clone and Navigate

```bash
cd /workspace/terraform/env-management/foundation-layer/terraform-cloud
```

### Step 2: Create terraform.tfvars

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
# IMPORTANT: Update the github_oauth_token_id with the value from Prerequisites step 2
```

Required values in `terraform.tfvars`:

```hcl
tfc_organization             = "Datafaced"
github_oauth_token_id        = "ot-xxxxxxxxxxxxx"  # From GitHub OAuth setup
github_repository_identifier = "dr3dr3/terraform"
vcs_branch                   = "main"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

This will:

- Download the TFE provider
- Connect to the `management-foundation-terraform-cloud` workspace
- Prepare for the first run

### Step 4: Plan Changes

```bash
terraform plan
```

Review the plan to see what will be created:

- 4 projects
- 6+ workspaces
- VCS connections for each workspace

### Step 5: Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm. This will:

- Create projects in Terraform Cloud
- Create workspaces with VCS integration
- Configure auto-apply settings
- Set working directories for each workspace

### Step 6: Verify in Terraform Cloud UI

1. Go to <https://app.terraform.io/app/Datafaced>
2. Check **Projects** → You should see:
   - `aws-management`
   - `aws-development`
   - `aws-sandbox`
   - `local-development`
3. Click into each project to see the workspaces
4. Each workspace should show:
   - ✅ Connected to GitHub repository `dr3dr3/terraform`
   - ✅ Working directory configured
   - ✅ Terraform version set

## Usage

### Adding a New Workspace

1. Edit `workspaces.tf`
2. Add a new `tfe_workspace` resource following the existing pattern
3. Run `terraform plan` and `terraform apply`

Example:

```hcl
resource "tfe_workspace" "dev_platform_networking" {
  name         = "development-platform-networking"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_development.id
  description  = "VPC and networking for development environment"

  vcs_repo {
    identifier     = local.vcs_repo.identifier
    oauth_token_id = local.vcs_repo.oauth_token_id
    branch         = local.vcs_repo.branch
  }

  working_directory = "terraform/env-development/platform-layer/networking"
  terraform_version = "~> 1.13.0"
  auto_apply        = var.auto_apply_dev

  tag_names = [
    "environment:development",
    "layer:platform",
    "aws-account:development"
  ]
}
```

### Updating Workspace Settings

Modify the workspace resource in `workspaces.tf` and apply:

```bash
terraform apply
```

### Adding Variable Sets

Create `variable-sets.tf` to manage shared variables across workspaces:

```hcl
resource "tfe_variable_set" "aws_credentials_dev" {
  name         = "AWS Development Account Credentials"
  description  = "AWS credentials for development account"
  organization = data.tfe_organization.main.name
}

resource "tfe_workspace_variable_set" "dev_foundation_iam_creds" {
  workspace_id    = tfe_workspace.dev_foundation_iam_terraform.id
  variable_set_id = tfe_variable_set.aws_credentials_dev.id
}
```

## Auto-Apply Settings

Different environments have different auto-apply configurations:

| Environment | Auto-Apply | Reason |
|-------------|------------|--------|
| Management | ❌ Disabled | Critical infrastructure, requires manual approval |
| Development | ✅ Enabled | Fast iteration, safe to auto-apply |
| Sandbox | ✅ Enabled | Experimental, safe to auto-apply |
| Meta-Terraform | ❌ Disabled | Changes affect all workspaces, requires review |

## Workspace Dependencies

Some workspaces depend on others. Recommended apply order:

1. **Management Foundation** → IAM roles and Identity Center
2. **Development Foundation** → IAM roles for dev account
3. **Development Applications** → EKS clusters and applications

Use Terraform Cloud **run triggers** to automate this (can be added to this configuration).

## Troubleshooting

### Error: Invalid OAuth Token ID

**Problem**: `github_oauth_token_id` is not set correctly

**Solution**:

1. Go to Terraform Cloud → Settings → Version Control
2. Find your GitHub connection
3. Copy the OAuth Token ID (format: `ot-xxxxxxxxxxxxx`)
4. Update `terraform.tfvars`

### Error: Workspace already exists

**Problem**: Workspace was manually created with the same name

**Solution**: Import the existing workspace:

```bash
terraform import tfe_workspace.management_foundation_iam_people Datafaced/management-foundation-iam-roles-for-people
```

### Error: TFE_TOKEN not set

**Problem**: Provider can't authenticate to Terraform Cloud

**Solution**: Set the token as environment variable:

```bash
set -gx TFE_TOKEN "your-token-here"
```

## Security Considerations

1. **Never commit `terraform.tfvars`** → Add to `.gitignore`
2. **Store TFE_TOKEN securely** → Use environment variables or credentials file
3. **Use organization tokens** → Preferred over user tokens for team usage
4. **Enable 2FA** → On Terraform Cloud account
5. **Review workspace permissions** → Limit who can approve applies

## Next Steps

After initial setup:

1. **Configure Variable Sets**: Add AWS credentials for each environment
2. **Set up Notifications**: Slack or email for workspace runs
3. **Add Run Triggers**: Automate dependent workspace runs
4. **Enable Sentinel Policies**: Add governance policies (requires Teams plan)
5. **Configure Team Access**: Set up RBAC for workspace access

## References

- [ADR-009: Folder Structure](/workspace/docs/reference/architecture-decision-register/ADR-009-folder-structure.md)
- [Terraform Cloud Projects Guide](/workspace/docs/explanations/terraform-cloud-projects.md)
- [TFE Provider Documentation](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs)
- [Terraform Cloud VCS Integration](https://developer.hashicorp.com/terraform/cloud-docs/vcs)
