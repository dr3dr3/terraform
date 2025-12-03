# Using 1Password with Terraform

This guide explains how to integrate 1Password with Terraform to securely manage secrets, variables, and configuration values across different scenarios.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Approach 1: Terraform Provider](#approach-1-terraform-provider)
- [Approach 2: 1Password CLI with Environment Variables](#approach-2-1password-cli-with-environment-variables)
- [Approach 3: 1Password Service Accounts](#approach-3-1password-service-accounts)
- [Approach 4: Using op inject for tfvars Files](#approach-4-using-op-inject-for-tfvars-files)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

We use different 1Password integration methods depending on the use case:

| Method | Use Case | When to Use |
|--------|----------|-------------|
| **Terraform Provider** | Creating 1Password items, reading secrets in Terraform code | Setting up new infrastructure, managing 1Password items as code |
| **CLI with Environment Variables** | GitHub OAuth tokens, API keys | Local development, sensitive credentials needed by Terraform providers |
| **Service Accounts** | CI/CD pipeline secrets | GitHub Actions, automated deployments |
| **op inject for tfvars** | Non-secret configuration (AWS account IDs, region names) | Values you don't want committed to public repos but aren't sensitive |

## Prerequisites

### Install 1Password CLI

```bash
# macOS
brew install 1password-cli

# Linux
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Windows
winget install 1Password.CLI
```

### Verify Installation

```bash
op --version
```

### Sign In (Local Development)

```bash
# Interactive sign-in
eval $(op signin)

# Or set up biometric unlock for easier authentication
```

## Approach 1: Terraform Provider

**Use for:** Creating and managing 1Password items as part of your infrastructure code, reading secrets for resource configuration.

### Setup

Add the 1Password provider to your Terraform configuration:

```hcl
# versions.tf
terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.1"
    }
  }
}

provider "onepassword" {
  # Authentication handled via 1Password CLI session or service account token
  # No explicit credentials needed here
}
```

### Creating 1Password Items

Use this to store Terraform outputs or create secrets as part of your infrastructure:

```hcl
# Create a vault for infrastructure secrets
resource "onepassword_vault" "infrastructure" {
  name        = "Infrastructure"
  description = "Terraform-managed infrastructure secrets"
}

# Store database credentials
resource "onepassword_item" "database" {
  vault    = onepassword_vault.infrastructure.uuid
  title    = "Production Database"
  category = "database"

  username = "admin"
  password = random_password.db_password.result
  url      = aws_db_instance.main.endpoint

  section {
    label = "AWS Details"
    
    field {
      label = "Region"
      type  = "STRING"
      value = var.aws_region
    }
    
    field {
      label = "Instance ID"
      type  = "STRING"
      value = aws_db_instance.main.id
    }
  }
}

# Store API keys
resource "onepassword_item" "api_keys" {
  vault    = onepassword_vault.infrastructure.uuid
  title    = "AWS API Keys"
  category = "api_credential"

  username = aws_iam_access_key.terraform.id
  password = aws_iam_access_key.terraform.secret
}
```

### Reading Secrets from 1Password

Reference existing 1Password items in your Terraform code:

```hcl
# Read existing secrets
data "onepassword_item" "github_token" {
  vault = "terraform"
  title = "GitHub OAuth Token"
}

data "onepassword_item" "datadog_api_key" {
  vault = "terraform"
  title = "Datadog API Key"
}

# Use in resources
resource "github_repository" "example" {
  name = "my-repo"
  
  # Provider will use the token from 1Password
  # Configure provider elsewhere with the token
}

# Store in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "datadog" {
  secret_id     = aws_secretsmanager_secret.datadog.id
  secret_string = data.onepassword_item.datadog_api_key.password
}
```

### Authentication for Provider

The provider authenticates using your existing 1Password CLI session:

```bash
# Ensure you're signed in
eval $(op signin)

# Run Terraform
terraform plan
terraform apply
```

## Approach 2: 1Password CLI with Environment Variables

**Use for:** Sensitive credentials like GitHub OAuth tokens, API keys that Terraform providers need.

### Create .envrc Template

Create a template file that won't be committed:

```bash
# .envrc.template (commit this)
export TF_VAR_github_token="op://terraform/GitHub-OAuth-Token/credential"
export TF_VAR_datadog_api_key="op://terraform/Datadog/api_key"
export TF_VAR_datadog_app_key="op://terraform/Datadog/app_key"
export AWS_ACCESS_KEY_ID="op://terraform/AWS-Terraform-User/access_key_id"
export AWS_SECRET_ACCESS_KEY="op://terraform/AWS-Terraform-User/secret_access_key"
```

### Using op run

Execute Terraform commands with secrets injected:

```bash
# Run plan with secrets
op run --env-file=".envrc.template" -- terraform plan

# Run apply with secrets
op run --env-file=".envrc.template" -- terraform apply

# Or use in shell
op run --env-file=".envrc.template" -- bash
# Now all environment variables are available in this shell session
terraform plan
```

### Configure Providers

Reference the environment variables in your provider configuration:

```hcl
# providers.tf
provider "github" {
  token = var.github_token  # From TF_VAR_github_token
}

provider "datadog" {
  api_key = var.datadog_api_key  # From TF_VAR_datadog_api_key
  app_key = var.datadog_app_key  # From TF_VAR_datadog_app_key
}

provider "aws" {
  region = var.aws_region
  # Credentials from AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars
}
```

### Variable Declarations

```hcl
# variables.tf
variable "github_token" {
  description = "GitHub OAuth token for provider authentication"
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key"
  type        = string
  sensitive   = true
}
```

### Add to .gitignore

```gitignore
# .gitignore
.envrc
*.env
!*.env.template
!.envrc.template
```

## Approach 3: 1Password Service Accounts

**Use for:** CI/CD pipelines, GitHub Actions, automated deployments where interactive authentication isn't possible.

### Create Service Account

1. Go to 1Password → Settings → Service Accounts
2. Create a new service account with descriptive name: `terraform-cicd`
3. Grant access to specific vaults (e.g., "terraform")
4. Copy the service account token (starts with `ops_`)

### Store in GitHub Secrets

Add to your repository secrets:

- Secret name: `OP_SERVICE_ACCOUNT_TOKEN`
- Value: Your service account token

### GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Terraform Init
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          op run --env-file=".envrc.template" -- terraform init

      - name: Terraform Plan
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          op run --env-file=".envrc.template" -- terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          op run --env-file=".envrc.template" -- terraform apply -auto-approve tfplan
```

### Service Account Best Practices

- Create separate service accounts for different environments (dev, staging, prod)
- Use descriptive names: `terraform-prod-cicd`, `terraform-dev-cicd`
- Grant minimum required vault access
- Rotate tokens periodically
- Monitor service account usage in 1Password Activity logs

## Approach 4: Using op inject for tfvars Files

**Use for:** Non-secret configuration values that you don't want in public repos (AWS account IDs, region names, project identifiers).

### Create tfvars Template

```hcl
# terraform.tfvars.template (commit this)
aws_account_id         = "op://terraform/AWS-Accounts/production_account_id"
aws_region             = "op://terraform/AWS-Config/default_region"
environment            = "op://terraform/Environment-Config/name"
project_name           = "op://terraform/Project-Config/name"
eks_cluster_name       = "op://terraform/EKS-Config/cluster_name"
vpc_cidr               = "op://terraform/Network-Config/vpc_cidr"

# Organization details
organization_name      = "op://terraform/Organization/name"
cost_center           = "op://terraform/Organization/cost_center"
team_name             = "op://terraform/Organization/team_name"

# Non-sensitive but environment-specific
datadog_site          = "op://terraform/Datadog/site"
log_retention_days    = "op://terraform/Logging-Config/retention_days"
backup_retention_days = "op://terraform/Backup-Config/retention_days"
```

### Store Values in 1Password

Create an item in 1Password with these fields:

```text
Vault: terraform
Item: AWS-Accounts
Fields:
  - production_account_id: 123456789012
  - staging_account_id: 210987654321
  - dev_account_id: 567890123456

Item: AWS-Config
Fields:
  - default_region: ap-southeast-2
  - backup_region: ap-southeast-1

Item: Environment-Config
Fields:
  - name: production
```

### Generate tfvars File

```bash
# Generate terraform.tfvars from template
op inject -i terraform.tfvars.template -o terraform.tfvars

# Verify the output
cat terraform.tfvars
```

### Use in Terraform Workflow

```bash
# Full workflow
op inject -i terraform.tfvars.template -o terraform.tfvars
op run --env-file=".envrc.template" -- terraform plan
op run --env-file=".envrc.template" -- terraform apply

# Or create a helper script
# scripts/tf-plan.sh
#!/bin/bash
set -e

echo "Generating terraform.tfvars from template..."
op inject -i terraform.tfvars.template -o terraform.tfvars

echo "Running terraform plan..."
op run --env-file=".envrc.template" -- terraform plan "$@"
```

### Add .gitignore

```gitignore
# .gitignore
terraform.tfvars
*.auto.tfvars
!*.tfvars.template
```

### Variable Declarations - Approach 4

```bash
# variables.tf
variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

# Add validation where appropriate
variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

## Best Practices

### Organization in 1Password

Structure your vaults and items logically:

```text
terraform Vault
├── AWS-Accounts (account IDs for all environments)
├── AWS-Config (regions, default settings)
├── GitHub-OAuth-Token (for Terraform provider)
├── Datadog (API keys, site configuration)
├── Environment-Config (environment names, settings)
├── Project-Config (project metadata)
└── Secrets/
    ├── Database-Production
    ├── Database-Staging
    └── API-Keys-Production
```

### Secret Reference Format

Use consistent 1Password secret reference format:

```text
op://[vault-name]/[item-name]/[field-name]
op://terraform/GitHub-OAuth-Token/credential
op://terraform/AWS-Accounts/production_account_id
```

### Template Files in Git

Always commit template files, never actual values:

```bash
# Commit these
git add terraform.tfvars.template
git add .envrc.template
git add .env.template

# Never commit these
terraform.tfvars  # in .gitignore
.envrc           # in .gitignore
.env             # in .gitignore
```

### Pre-commit Hook

Create a pre-commit hook to prevent accidental commits:

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Check for sensitive files
SENSITIVE_FILES=("terraform.tfvars" ".envrc" ".env")

for file in "${SENSITIVE_FILES[@]}"; do
  if git diff --cached --name-only | grep -q "^$file$"; then
    echo "ERROR: Attempting to commit sensitive file: $file"
    echo "Only commit .template versions of these files"
    exit 1
  fi
done

# Check for 1Password tokens in code
if git diff --cached | grep -q "ops_"; then
  echo "ERROR: Possible 1Password service account token detected"
  echo "Never commit service account tokens"
  exit 1
fi

exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

### Documentation in Repository

Include a README section explaining the setup:

```markdown
## 1Password Setup

This repository uses 1Password for secrets management. See [docs/1password-terraform-guide.md](docs/1password-terraform-guide.md) for full details.

### First-time Setup

1. Install 1Password CLI: `brew install 1password-cli`
2. Sign in: `eval $(op signin)`
3. Generate tfvars: `op inject -i terraform.tfvars.template -o terraform.tfvars`
4. Run Terraform: `op run --env-file=".envrc.template" -- terraform plan`

### Required 1Password Items

Ensure you have access to these items in the terraform vault:
- GitHub-OAuth-Token
- AWS-Accounts
- Datadog
- Environment-Config
```

## Troubleshooting

### Authentication Issues

```bash
# Check if signed in
op account list

# Sign in again
eval $(op signin)

# For service accounts, verify token
echo $OP_SERVICE_ACCOUNT_TOKEN
```

### Secret References Not Resolving

```bash
# Test a specific reference
op read "op://terraform/GitHub-OAuth-Token/credential"

# Verify item exists
op item list --vault terraform

# Check field names
op item get "GitHub-OAuth-Token" --vault terraform
```

### Template File Errors

```bash
# Validate template syntax
op inject -i terraform.tfvars.template -o /dev/null

# Dry run to see what would be generated
op inject -i terraform.tfvars.template
```

### CI/CD Pipeline Issues

```yaml
# Add debugging to workflow
- name: Debug 1Password
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
  run: |
    echo "Checking 1Password CLI..."
    op --version
    echo "Testing vault access..."
    op vault list
    echo "Testing item read..."
    op item get "GitHub-OAuth-Token" --vault terraform
```

### Permission Errors

If you get permission errors:

1. Verify vault access in 1Password
2. Check service account permissions
3. Ensure item exists with correct name
4. Verify field names match exactly

### Terraform Provider Issues

```bash
# Verify provider can authenticate
terraform init

# Enable debug logging
export TF_LOG=DEBUG
terraform plan
```

## Further Reading

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [1Password Terraform Provider](https://registry.terraform.io/providers/1Password/onepassword/latest/docs)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [Secret References](https://developer.1password.com/docs/cli/secret-references/)
