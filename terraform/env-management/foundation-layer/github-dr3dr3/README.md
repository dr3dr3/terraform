# GitHub Repositories Management

This Terraform configuration manages GitHub repositories for the `dr3dr3` GitHub account. It provides centralized management of repository settings, branch protection, environments, and GitHub Actions configuration.

## Overview

This workspace manages the following aspects of GitHub repositories:

- **Repository Settings**: Visibility, features (issues, wiki, projects, discussions), merge options
- **Branch Protection**: Rulesets for protected branches with PR requirements
- **Repository Environments**: Deployment environments with protection rules
- **Repository Variables**: Non-sensitive configuration values for GitHub Actions
- **Repository Secrets**: Sensitive values for GitHub Actions (managed via TFC variables)

## Managed Repositories

| Repository | Description | Visibility |
|------------|-------------|------------|
| terraform | Infrastructure as Code with Terraform | Public |
| platform | Platform engineering configurations | Public |
| ai | AI/ML projects and experiments | Public |
| kubernetes | Kubernetes manifests and configurations | Public |
| k8s-homelab-admin | Homelab Kubernetes administration | Public |
| kubestronaut | Kubernetes certification prep | Public |
| rag | Retrieval Augmented Generation projects | Public |
| template-devcontainer | Dev Container template repository | Public |
| dotfiles | Personal dotfiles and configurations | Public |
| terraform-modules | Reusable Terraform modules | Public |
| k8s-homelab-manifests | Homelab Kubernetes manifests | Public |

## Prerequisites

### GitHub Authentication

This workspace requires a **Fine-Grained Personal Access Token** scoped to specific repositories with minimal permissions. GitHub recommends fine-grained tokens over classic tokens for improved security.

#### Creating a Fine-Grained Personal Access Token

1. **Navigate to Token Settings**

   Go to: <https://github.com/settings/personal-access-tokens/new>

   Or use the direct link with pre-filled permissions:

   ```text
   https://github.com/settings/personal-access-tokens/new
     ?name=Terraform+GitHub+Repos+Management
     &description=Terraform+Cloud+workspace+for+managing+dr3dr3+repositories
     &expires_in=90
     &administration=write
     &contents=read
     &environments=write
     &metadata=read
     &secrets=write
     &actions_variables=write
     &secret_scanning_alerts=read
   ```

2. **Token Configuration**

   | Setting | Value |
   |---------|-------|
   | **Token name** | `Terraform GitHub Repos Management` |
   | **Expiration** | 90 days (recommended) or custom |
   | **Description** | Terraform Cloud workspace for managing dr3dr3 repositories |
   | **Resource owner** | `dr3dr3` (your personal account) |

3. **Repository Access**

   Select **"Only select repositories"** and choose:

   - `terraform`
   - `platform`
   - `ai`
   - `kubernetes`
   - `k8s-homelab-admin`
   - `kubestronaut`
   - `rag`
   - `template-devcontainer`
   - `dotfiles`
   - `terraform-modules`
   - `k8s-homelab-manifests`

4. **Required Permissions**

   Set these **Repository Permissions**:

   | Permission | Access Level | Purpose |
   |------------|--------------|---------|
   | **Administration** | Read and write | Create/update repos, manage settings, topics, rulesets |
   | **Contents** | Read | Read repository contents (required for settings) |
   | **Environments** | Read and write | Create/manage deployment environments |
   | **Metadata** | Read | Required base permission (auto-selected) |
   | **Secret scanning alerts** | Read | Read vulnerability alerts status (required for `vulnerability_alerts` attribute) |
   | **Secrets** | Read and write | Manage GitHub Actions secrets |
   | **Variables** | Read and write | Manage GitHub Actions variables |

   > **Note**: No Account or Organization permissions are needed for personal repositories.

5. **Generate and Store the Token**

   - Click **"Generate token"**
   - Copy the token immediately (it won't be shown again)
   - Token format: `github_pat_xxxxxxxxxxxxx`

#### Setting Up in Terraform Cloud

Add the token as an **environment variable** in your Terraform Cloud workspace:

| Variable | Category | Value | Sensitive |
|----------|----------|-------|-----------|
| `GITHUB_TOKEN` | Environment variable | `github_pat_xxxxxxxxxxxxx` | ✅ Yes |

Alternatively, set it in Terraform Cloud via CLI:

```bash
# Using Terraform Cloud CLI (if configured)
tfe_workspace_id="ws-xxxxx"

# Or via environment variable for local runs
export GITHUB_TOKEN="github_pat_xxxxxxxxxxxxx"
```

#### Token Security Best Practices

- ✅ Use fine-grained tokens instead of classic tokens
- ✅ Scope to specific repositories only
- ✅ Grant minimal required permissions
- ✅ Set an expiration date (90 days recommended)
- ✅ Rotate tokens before expiration
- ✅ Store tokens as sensitive variables in Terraform Cloud
- ❌ Never commit tokens to version control
- ❌ Never share tokens in plaintext

#### Permissions Reference

The GitHub Provider requires these API permissions for each resource type:

| Terraform Resource | API Permission Required |
|--------------------|------------------------|
| `github_repository` | Administration (write) |
| `github_repository` (vulnerability_alerts) | Secret scanning alerts (read) |
| `github_repository_ruleset` | Administration (write) |
| `github_repository_environment` | Administration (write) for creation, Environments (write) for secrets/variables |
| `github_actions_secret` | Secrets (write) |
| `github_actions_variable` | Variables (write) |
| `github_branch_protection_v3` | Administration (write) |

For full permission details, see [GitHub's REST API documentation](https://docs.github.com/en/rest/overview/permissions-required-for-fine-grained-personal-access-tokens).

### Terraform Cloud

This workspace is designed to run in Terraform Cloud with:

- **Organization**: Datafaced
- **Workspace**: management-foundation-github-repositories
- **Trigger**: CLI-driven (per ADR-014 for foundation layer)
- **Required Variables**: `GITHUB_TOKEN` (environment variable, sensitive)

## Usage

### Initialize and Plan

```bash
cd terraform/env-management/foundation-layer/github-repositories
terraform init
terraform plan
```

### Apply Changes

```bash
terraform apply
```

### Import Existing Repositories

If repositories already exist, import them before applying:

```bash
# Import each repository
terraform import 'github_repository.repos["terraform"]' terraform
terraform import 'github_repository.repos["platform"]' platform
terraform import 'github_repository.repos["ai"]' ai
# ... repeat for all repositories
```

## Configuration

### Adding a New Repository

Add a new entry to the `repositories` local in `main.tf`:

```hcl
"new-repo" = {
  description = "Description of the new repository"
  topics      = ["topic1", "topic2"]
  homepage    = ""
  visibility  = "public"

  has_issues      = true
  has_discussions = false

  protected_branches = ["main"]
  environments       = ["development", "production"]
}
```

### Managing Repository Secrets

Repository secrets should be managed via Terraform Cloud workspace variables. Add them as sensitive variables in TFC, then reference them in `repositories.tf`.

### Customizing Branch Protection

Edit the `github_repository_ruleset.main_branch` resource in `repositories.tf` to customize branch protection rules.

## Outputs

| Output | Description |
|--------|-------------|
| `repositories` | Map of all managed repositories with their details |
| `repository_names` | List of all managed repository names |
| `repository_urls` | Map of repository names to their HTML URLs |
| `repository_count` | Number of repositories managed |
| `environments` | Map of all repository environments |
| `protected_branches` | Map of repositories with protected branches |

## Architecture Decisions

- **ADR-014**: CLI-driven workflow for foundation layer (requires manual approval)
- **Rulesets vs Branch Protection**: Uses newer GitHub Rulesets API for better flexibility
- **Archive on Destroy**: Repositories are archived instead of deleted for safety

## Future Enhancements

- [ ] GitHub Actions workflow templates management
- [ ] CODEOWNERS file management
- [ ] Dependabot configuration
- [ ] Security policy management
- [ ] Issue and PR templates
- [ ] GitHub Pages configuration
- [ ] Repository webhooks
- [ ] Team/collaborator access management

## Related Documentation

- [GitHub Provider Documentation](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [GitHub Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Repository Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
