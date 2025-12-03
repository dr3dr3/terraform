# GitHub Copilot Instructions

## Available Copilot Agents

Custom agents are available in `.github/copilot-agents/`:

| Agent | Purpose | How to Use |
|-------|---------|------------|
| [commit-and-pr](copilot-agents/commit-and-pr.md) | Commit changes and create a PR | Say: "Commit my changes and create a PR" |

## Markdown Formatting Rules

When creating or editing Markdown files, follow these linting rules to ensure consistency and avoid common errors:

### Fenced Code Blocks

1. **Always surround fenced code blocks with blank lines** (MD031)
   - Add a blank line before the opening fence (\`\`\`)
   - Add a blank line after the closing fence (\`\`\`)
   
   ✅ Good:
   ```markdown
   Some text here.
   
   ```bash
   echo "hello"
   ```
   
   More text here.
   ```
   
   ❌ Bad:
   ```markdown
   Some text here.
   ```bash
   echo "hello"
   ```
   More text here.
   ```

2. **Always specify a language for fenced code blocks** (MD040)
   - Use appropriate language identifiers: `bash`, `python`, `javascript`, `text`, `json`, etc.
   - For plain text or pseudocode, use `text`
   
   ✅ Good:
   ````markdown
   ```bash
   npm install
   ```
   ````
   
   ❌ Bad:
   ````markdown
   ```
   npm install
   ```
   ````

### Lists

3. **Surround lists with blank lines** (MD032)
   - Add a blank line before the first list item
   - Add a blank line after the last list item
   
   ✅ Good:
   ```markdown
   Here are the steps:
   
   - First step
   - Second step
   - Third step
   
   Now continue with...
   ```
   
   ❌ Bad:
   ```markdown
   Here are the steps:
   - First step
   - Second step
   - Third step
   Now continue with...
   ```

### File Structure

4. **End files with a single newline character** (MD047)
   - Ensure the last line of the file is followed by exactly one newline
   - Most editors handle this automatically, but verify for generated content

### Nested Code Blocks in Lists

When including code blocks within numbered or bulleted lists, maintain proper indentation and blank lines:

✅ Good:
```markdown
1. First step description:

   ```bash
   command here
   ```

2. Second step description:
```

❌ Bad:
```markdown
1. First step description:
   ```bash
   command here
   ```

2. Second step description:
```

### Summary Checklist

When writing Markdown:

- [ ] Blank line before opening code fence
- [ ] Blank line after closing code fence
- [ ] Language specified for all code blocks
- [ ] Blank line before lists
- [ ] Blank line after lists
- [ ] File ends with single newline

### Quick Reference Table

| Rule | Code | What to Do |
|------|------|------------|
| Blank lines around fences | MD031 | Add blank lines before and after \`\`\` |
| Specify code language | MD040 | Add language after opening \`\`\` (bash, text, etc.) |
| Blank lines around lists | MD032 | Add blank lines before and after list blocks |
| Single trailing newline | MD047 | Ensure file ends with one newline |

These rules ensure markdown files are properly formatted and pass standard linting tools like markdownlint.

## Terraform Folder Naming Conventions

Terraform configuration folders under `/terraform` must align with their corresponding Terraform Cloud workspace names for intuitive navigation between the codebase and Terraform Cloud UI.

### Naming Pattern

Terraform Cloud workspace names follow this pattern:

```text
{environment}-{layer}-{component}
```

The folder structure must match:

```text
/terraform/env-{environment}/{layer}-layer/{component}/
```

### Alignment Rules

1. **The folder name must match the workspace name component**
   - The `{component}` portion of the workspace name should exactly match the folder name
   - This enables easy association between Terraform Cloud UI and the repository

2. **Use the full descriptive name, not abbreviations**
   - Workspace: `development-foundation-gha-oidc` → Folder: `gha-oidc/`
   - Workspace: `management-foundation-iam-roles-for-people` → Folder: `iam-roles-for-people/`
   - Workspace: `sandbox-platform-eks` → Folder: `eks/`

### Examples

| Terraform Cloud Workspace | Folder Path |
|---------------------------|-------------|
| `development-foundation-gha-oidc` | `/terraform/env-development/foundation-layer/gha-oidc/` |
| `development-foundation-iam-roles-for-terraform` | `/terraform/env-development/foundation-layer/iam-roles-for-terraform/` |
| `management-foundation-tfc-oidc-role` | `/terraform/env-management/foundation-layer/tfc-oidc-role/` |
| `management-foundation-iam-roles-for-people` | `/terraform/env-management/foundation-layer/iam-roles-for-people/` |
| `sandbox-platform-eks` | `/terraform/env-sandbox/platform-layer/eks/` |
| `development-platform-eks` | `/terraform/env-development/platform-layer/eks/` |

### Working Directory Configuration

When creating Terraform Cloud workspaces, the `working_directory` attribute must point to the correct folder path:

```hcl
resource "tfe_workspace" "example" {
  name              = "development-foundation-gha-oidc"
  working_directory = "terraform/env-development/foundation-layer/gha-oidc"
  # ...
}
```

### Migration Checklist

When renaming folders to align with workspace names:

- [ ] Rename the folder to match the workspace component name
- [ ] Update the `working_directory` in the Terraform Cloud workspace configuration
- [ ] Update any references in documentation
- [ ] Verify VCS trigger paths if using VCS-driven workflows
