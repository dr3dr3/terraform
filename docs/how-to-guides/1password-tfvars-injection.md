# Using 1Password CLI to Inject Terraform Variables

## Overview

This guide explains how to use 1Password CLI to securely inject sensitive values into Terraform `.tfvars` files without committing secrets to version control.

## Prerequisites

1. **1Password CLI installed**: Install from [1Password CLI documentation](https://developer.1password.com/docs/cli/get-started/)
2. **1Password account** with a vault for storing Terraform secrets
3. **Authenticated CLI**: Run `op signin` to authenticate

## How It Works

1. Store sensitive Terraform variables in 1Password items
2. Reference these secrets in `.tfvars.example` files using 1Password secret reference syntax
3. Use `op inject` to populate actual `.tfvars` files from the templates
4. The populated `.tfvars` files are gitignored and never committed

## Setting Up Your 1Password Vault

### 1. Create a Vault (Recommended)

Create a dedicated vault for Terraform secrets:

```bash
op vault create "Terraform"
```

### 2. Store Terraform Variables

Create items in 1Password for each environment or service. Example for Terraform Cloud:

```bash
op item create \
  --category=login \
  --title="Terraform Cloud - Management" \
  --vault="Terraform" \
  github_oauth_token_id="ot-XXXXXXXXXXXXXX"
```

Or use the 1Password GUI to create items with custom fields.

## Structuring Your Items

### Recommended Structure

Organize items by environment and layer:

- **Terraform Cloud - Management**: TFC organization settings
- **AWS - Development**: AWS-specific variables for dev
- **AWS - Sandbox**: AWS-specific variables for sandbox
- **GitHub - CI/CD**: GitHub tokens and identifiers

### Custom Fields

For each item, add custom fields matching your tfvars variable names:

- `github_oauth_token_id`
- `tfc_organization`
- `github_repository_identifier`
- etc.

## Using Secret References in Templates

### Syntax

1Password secret references use this format:

```text
op://vault-name/item-name/field-name
```

### Example: terraform.tfvars.tpl

Create template files with `.tpl` extension (or use `.tfvars.example`):

```hcl
# Terraform Cloud Organization
tfc_organization = "Datafaced"

# GitHub VCS Integration - Stored in 1Password
github_oauth_token_id = "op://Terraform/Terraform Cloud - Management/github_oauth_token_id"

# GitHub Repository
github_repository_identifier = "dr3dr3/terraform"

# VCS Branch
vcs_branch = "main"

# Tags
owner       = "Platform-Team"
cost_center = "Infrastructure"

# Auto-Apply Settings
auto_apply_dev        = true
auto_apply_sandbox    = true
auto_apply_management = false
```

## Injecting Values

### Manual Injection

Use `op inject` to populate the actual tfvars file:

```bash
cd terraform/env-management/foundation-layer/terraform-cloud
op inject -i terraform.tfvars.example -o terraform.tfvars
```

### Automated Script

Create a script to inject all tfvars files at once:

```bash
#!/usr/bin/env bash
# inject-tfvars.sh

find terraform -name "terraform.tfvars.example" | while read -r example_file; do
    tfvars_file="${example_file%.example}"
    echo "Injecting: $tfvars_file"
    op inject -i "$example_file" -o "$tfvars_file"
done
```

Make it executable and run:

```bash
chmod +x inject-tfvars.sh
./inject-tfvars.sh
```

## Workflow

### Initial Setup

1. Store all sensitive values in 1Password
2. Update `.tfvars.example` files with 1Password references for sensitive fields
3. Run injection to create actual `.tfvars` files
4. Verify gitignore is working (`.tfvars` files should not be tracked)

### Daily Development

1. Pull latest changes
2. Run `op inject` to update your local `.tfvars` files
3. Work with Terraform normally
4. Only commit changes to `.tfvars.example` files (with secret references)

### Adding New Secrets

1. Add the secret to 1Password item
2. Update `.tfvars.example` with the reference: `op://vault/item/field`
3. Run injection to populate `.tfvars`
4. Commit the updated `.tfvars.example`

## Best Practices

### 1. Separate Public and Private Values

Not everything needs to be in 1Password. Only store:

- API tokens and OAuth tokens
- Sensitive identifiers
- Credentials
- Private keys

Keep non-sensitive configuration in plain text in the `.tfvars.example` files.

### 2. Document Secret References

Add comments in `.tfvars.example` to indicate what each secret is and where to find it:

```hcl
# Get this from Terraform Cloud UI: Settings -> Version Control -> OAuth Clients
# Stored in: 1Password -> Terraform vault -> "Terraform Cloud - Management"
github_oauth_token_id = "op://Terraform/Terraform Cloud - Management/github_oauth_token_id"
```

### 3. Automate Injection

Add injection to your Taskfile or Makefile:

```yaml
# Taskfile.yml
tasks:
  inject-tfvars:
    desc: Inject 1Password secrets into tfvars files
    cmds:
      - |
        find terraform -name "terraform.tfvars.example" | while read -r example; do
          op inject -i "$example" -o "${example%.example}"
        done
```

### 4. CI/CD Integration

For automated pipelines, use 1Password Service Accounts:

```bash
# In CI/CD, authenticate with service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-token"

# Then inject works without interactive signin
op inject -i terraform.tfvars.example -o terraform.tfvars
```

### 5. Verification

After injection, verify sensitive values were populated:

```bash
# Check that references were replaced (should show actual values, not op:// references)
grep -v "^#" terraform.tfvars | grep -v "^$"
```

## Troubleshooting

### Secret Reference Not Found

```text
Error: secret reference "op://..." could not be resolved
```

**Solution**: Verify the vault name, item name, and field name are correct. Use `op item get "Item Name" --vault "Vault Name"` to check.

### Authentication Required

```text
Error: not signed in
```

**Solution**: Run `op signin` to authenticate.

### File Not Being Populated

**Solution**: Ensure your 1Password reference syntax is exact:

- Vault name matches exactly (case-sensitive)
- Item name matches exactly
- Field name matches the custom field in 1Password

### Multiple Accounts

If you have multiple 1Password accounts:

```bash
# List accounts
op account list

# Use specific account
op inject -i input.tpl -o output.txt --account "Work"
```

## Security Considerations

1. **Never commit `.tfvars` files**: Verified by gitignore
2. **Rotate secrets regularly**: Update in 1Password, then re-inject
3. **Use service accounts for CI/CD**: Don't use personal accounts in automation
4. **Audit access**: Review who has access to your Terraform vault
5. **Use MFA**: Enable multi-factor authentication for 1Password

## Additional Resources

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [1Password Secret References](https://developer.1password.com/docs/cli/secrets-reference-syntax/)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
