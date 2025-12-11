# How to Create a GitHub Repository from a Template

## Overview

This guide explains how to create a new GitHub repository from an existing template repository using the Terraform configuration in `env-management/foundation-layer/github-dr3dr3`.

## Prerequisites

- Template repository already exists (e.g., `template-devcontainer`)
- Access to the `github-dr3dr3` Terraform workspace
- GitHub provider configured with appropriate permissions

## Step 1: Add Template Support to Terraform Code

If not already present, add the `template` block support to `repositories.tf`:

```terraform
resource "github_repository" "repos" {
  for_each = local.repositories

  name         = each.key
  description  = each.value.description
  visibility   = lookup(each.value, "visibility", var.default_visibility)
  homepage_url = lookup(each.value, "homepage", null)
  topics       = lookup(each.value, "topics", [])

  # Features
  has_issues      = lookup(each.value, "has_issues", var.default_has_issues)
  has_projects    = lookup(each.value, "has_projects", var.default_has_projects)
  has_wiki        = lookup(each.value, "has_wiki", var.default_has_wiki)
  has_downloads   = lookup(each.value, "has_downloads", var.default_has_downloads)
  has_discussions = lookup(each.value, "has_discussions", var.default_has_discussions)

  # Template settings
  is_template = lookup(each.value, "is_template", false)

  # Create from template (if specified)
  dynamic "template" {
    for_each = lookup(each.value, "template", null) != null ? [each.value.template] : []
    content {
      owner                = template.value.owner
      repository           = template.value.repository
      include_all_branches = lookup(template.value, "include_all_branches", false)
    }
  }

  # ... rest of configuration
}
```

## Step 2: Define New Repository in main.tf

Add the new repository definition to the `local.repositories` map in `main.tf`:

```terraform
locals {
  repositories = {
    # ... existing repositories ...

    "my-new-project" = {
      description = "New project created from template"
      topics      = ["project", "example", "devcontainer"]
      homepage    = ""
      visibility  = "public"

      # Specify the template to use
      template = {
        owner                = "dr3dr3"
        repository           = "template-devcontainer"
        include_all_branches = false  # Usually false - only copy main branch
      }

      # Repository features
      has_issues      = true
      has_discussions = false
      has_wiki        = false
      has_projects    = true

      # Branch protection
      protected_branches = ["main"]

      # Environments (if needed)
      environments = ["development", "production"]
    }
  }
}
```

## Step 3: Apply Terraform Configuration

Navigate to the workspace directory and apply:

```bash
cd /workspace/terraform/env-management/foundation-layer/github-dr3dr3

# Review the plan
terraform plan

# Apply the changes
terraform apply
```

## Step 4: Verify Repository Creation

Check that the repository was created successfully:

```bash
# Using GitHub CLI
gh repo view dr3dr3/my-new-project

# Or check in browser
open https://github.com/dr3dr3/my-new-project
```

## Step 5: Clean Up Template Block (Optional)

After the repository is created, you can optionally remove the `template` block from `main.tf` to keep the configuration clean:

```terraform
"my-new-project" = {
  description = "New project created from template"
  topics      = ["project", "example", "devcontainer"]
  
  # template block removed - no longer needed after initial creation
  
  protected_branches = ["main"]
  environments       = ["development", "production"]
}
```

Apply again to update state:

```bash
terraform apply
```

## Important Notes

### Template Block Behavior

- The `template` block only takes effect during **initial repository creation**
- On subsequent Terraform runs, the block is ignored (repository already exists)
- Leaving the block in place won't cause issues, but removing it keeps config cleaner
- The template block serves as documentation showing the repository origin

### What Gets Copied

When creating from a template:

- ✅ Files and directory structure
- ✅ Branches (if `include_all_branches = true`)
- ✅ Commit history from template
- ❌ Issues, pull requests, discussions
- ❌ GitHub Actions workflow runs
- ❌ Secrets and variables
- ❌ Webhooks and integrations

### Template Repository Requirements

The template repository must have `is_template = true` set:

```terraform
"template-devcontainer" = {
  description = "Template repository for VS Code Dev Containers"
  is_template = true  # This makes it available as a template
  # ...
}
```

## Common Use Cases

### Creating Multiple Repos from Same Template

```terraform
"project-a" = {
  description = "Project A from template"
  template = {
    owner      = "dr3dr3"
    repository = "template-devcontainer"
  }
}

"project-b" = {
  description = "Project B from template"
  template = {
    owner      = "dr3dr3"
    repository = "template-devcontainer"
  }
}
```

### Using External Organization Template

```terraform
"new-project" = {
  description = "Project from external template"
  template = {
    owner      = "other-org"  # Different organization
    repository = "their-template"
  }
}
```

### Including All Branches

```terraform
"multi-branch-project" = {
  description = "Project with all template branches"
  template = {
    owner                = "dr3dr3"
    repository           = "template-devcontainer"
    include_all_branches = true  # Copy all branches, not just main
  }
}
```

## Troubleshooting

### Repository Already Exists

If the repository already exists in GitHub:

```text
Error: POST https://api.github.com/repos/dr3dr3/my-new-project:
422 Repository creation failed: name already exists
```

**Solution**: Either delete the existing repository or import it into Terraform state:

```bash
terraform import 'github_repository.repos["my-new-project"]' my-new-project
```

### Template Repository Not Found

```text
Error: template repository not found
```

**Solution**: Verify the template repository exists and is accessible:

```bash
gh repo view dr3dr3/template-devcontainer
```

### Permission Denied

```text
Error: 403 Forbidden
```

**Solution**: Ensure the GitHub token has `repo` scope and permissions to create repositories.

## Related Documentation

- [GitHub Provider: github_repository](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository)
- [Terraform Cloud OIDC Setup](terraform-cloud-oidc-setup-checklist.md)
- [Bootstrapping Guide](bootstrapping-guide.md)

## Workspace Location

```text
/workspace/terraform/env-management/foundation-layer/github-dr3dr3/
```
