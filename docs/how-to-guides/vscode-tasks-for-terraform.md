# VS Code Tasks for Terraform

> This guide explains what VS Code tasks are, why they're useful for Terraform work, and how to use them in this repository.
>
> **Current state:** This repository does not yet have a `tasks.json` file. This document explains the concept and includes ready-to-use configuration you can add.

---

## What Are VS Code Tasks?

VS Code tasks are shortcuts for terminal commands that you run repeatedly. Instead of typing `cd terraform/env-development/platform-layer/eks-auto-mode && terraform plan` every time, you can press `Ctrl+Shift+P` → `Tasks: Run Task` → `Dev EKS: Plan` and it runs automatically.

They live in `.vscode/tasks.json` (committed to the repo, so the whole team benefits).

Benefits for Terraform work:

- **No copy-paste errors** — the working directory, flags, and environment variables are pre-configured
- **IDE integration** — error output is parsed and linked to files in the Problems panel
- **Repeatable** — every developer runs commands the exact same way
- **Keyboard shortcut** — bind frequently used tasks (like `fmt`) to a key combo

---

## How to Use Tasks

### Running a Task

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type `Tasks: Run Task`
3. Select the task from the list

Or bind to a keyboard shortcut — see [Keyboard Shortcuts](#keyboard-shortcuts) below.

### Running the Default Build Task

If a task is marked as the `build` group default, press `Ctrl+Shift+B` to run it directly. A good candidate is `terraform fmt` — make it the default so you can format before committing.

### Viewing Task Output

Task output appears in the **Terminal** panel. If a problem matcher is configured (e.g., for `tflint`), errors are also shown in the **Problems** panel (`Ctrl+Shift+M`) and linked back to the relevant `.tf` file.

---

## Suggested Tasks for This Repository

Add this file as `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    // =========================================================================
    // Formatting & Validation (run these before every commit)
    // =========================================================================
    {
      "label": "terraform: fmt (all)",
      "type": "shell",
      "command": "terraform fmt -recursive",
      "options": { "cwd": "${workspaceFolder}" },
      "group": { "kind": "build", "isDefault": true },
      "presentation": { "reveal": "always", "panel": "shared" },
      "problemMatcher": []
    },
    {
      "label": "terraform: validate (current folder)",
      "type": "shell",
      "command": "terraform validate",
      "options": { "cwd": "${fileDirname}" },
      "group": "test",
      "presentation": { "reveal": "always", "panel": "shared" }
    },
    {
      "label": "checkov: scan terraform/",
      "type": "shell",
      "command": "checkov -d terraform/ --quiet",
      "options": { "cwd": "${workspaceFolder}" },
      "group": "test",
      "presentation": { "reveal": "always", "panel": "shared" }
    },

    // =========================================================================
    // Dev Environment — EKS Platform
    // =========================================================================
    {
      "label": "dev-eks: init",
      "type": "shell",
      "command": "terraform init",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-development/platform-layer/eks-auto-mode"
      },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "dev-eks: plan",
      "type": "shell",
      "command": "terraform plan -out=tfplan",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-development/platform-layer/eks-auto-mode"
      },
      "group": "none",
      "dependsOn": ["dev-eks: init"],
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "dev-eks: apply",
      "type": "shell",
      "command": "terraform apply tfplan",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-development/platform-layer/eks-auto-mode"
      },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "dev-eks: destroy",
      "type": "shell",
      "command": "terraform destroy",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-development/platform-layer/eks-auto-mode"
      },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },

    // =========================================================================
    // Management — Terraform Cloud workspaces
    // =========================================================================
    {
      "label": "mgmt-tfc: plan",
      "type": "shell",
      "command": "terraform plan",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-management/foundation-layer/terraform-cloud"
      },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "mgmt-tfc: apply",
      "type": "shell",
      "command": "terraform apply",
      "options": {
        "cwd": "${workspaceFolder}/terraform/env-management/foundation-layer/terraform-cloud"
      },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },

    // =========================================================================
    // Local Development — LocalStack
    // =========================================================================
    {
      "label": "localstack: start",
      "type": "shell",
      "command": "docker compose -f docker-compose.localstack.yml up -d",
      "options": { "cwd": "${workspaceFolder}" },
      "group": "none",
      "isBackground": true,
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "localstack: stop",
      "type": "shell",
      "command": "docker compose -f docker-compose.localstack.yml down",
      "options": { "cwd": "${workspaceFolder}" },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },

    // =========================================================================
    // Module Testing
    // =========================================================================
    {
      "label": "module-test: permission-set",
      "type": "shell",
      "command": "terraform test",
      "options": {
        "cwd": "${workspaceFolder}/terraform-modules/permission-set"
      },
      "group": "test",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "module-test: terraform-oidc-role",
      "type": "shell",
      "command": "terraform test",
      "options": {
        "cwd": "${workspaceFolder}/terraform-modules/terraform-oidc-role"
      },
      "group": "test",
      "presentation": { "reveal": "always", "panel": "dedicated" }
    }
  ]
}
```

---

## Setting Up the tasks.json File

```bash
mkdir -p .vscode
# Paste the JSON above into .vscode/tasks.json
```

Commit it to the repo so the whole team benefits:

```bash
git add .vscode/tasks.json
git commit -m "chore: add VS Code tasks for Terraform"
```

---

## Keyboard Shortcuts

To bind a specific task to a key combo, add to `.vscode/keybindings.json` (this file is personal, not committed):

```json
[
  {
    "key": "ctrl+shift+f",
    "command": "workbench.action.tasks.runTask",
    "args": "terraform: fmt (all)"
  },
  {
    "key": "ctrl+shift+p",
    "command": "workbench.action.tasks.runTask",
    "args": "dev-eks: plan"
  }
]
```

---

## Using `${fileDirname}` for Context-Aware Tasks

The `${fileDirname}` variable resolves to the directory of the currently open file. This is useful for a generic `terraform plan` task that works on whichever workspace you're editing:

```json
{
  "label": "terraform: plan (current workspace)",
  "type": "shell",
  "command": "terraform init && terraform plan",
  "options": { "cwd": "${fileDirname}" },
  "group": "none"
}
```

Open any `.tf` file in a workspace folder, run this task, and it will plan that specific workspace. No need for a separate task per environment.

---

## Problem Matchers

Problem matchers parse command output and link errors to specific files in the VS Code Problems panel. Terraform's output doesn't have a built-in matcher, but you can create a simple one for `tflint`:

```json
{
  "label": "tflint",
  "type": "shell",
  "command": "tflint --recursive",
  "options": { "cwd": "${workspaceFolder}/terraform" },
  "problemMatcher": {
    "owner": "tflint",
    "fileLocation": ["relative", "${workspaceFolder}"],
    "pattern": {
      "regexp": "^(.+):(\\d+):(\\d+): (error|warning|notice): (.+)$",
      "file": 1,
      "line": 2,
      "column": 3,
      "severity": 4,
      "message": 5
    }
  }
}
```

---

## Recommended Extensions

These VS Code extensions complement the Terraform tasks:

| Extension | ID | What It Adds |
|---|---|---|
| HashiCorp Terraform | `hashicorp.terraform` | Syntax highlighting, auto-complete, hover docs, `terraform fmt` on save |
| AWS Toolkit | `amazonwebservices.aws-toolkit-vscode` | Browse AWS resources, CloudWatch Logs viewer |
| GitLens | `eamodio.gitlens` | Inline git blame — helpful when reviewing who changed a resource config |
| YAML | `redhat.vscode-yaml` | Schema validation for `docker-compose.localstack.yml` and GHA workflows |

Install the Terraform extension and enable format-on-save to make the `fmt` task less necessary:

```json
// .vscode/settings.json
{
  "[terraform]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "hashicorp.terraform"
  },
  "[terraform-vars]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "hashicorp.terraform"
  }
}
```

Commit `.vscode/settings.json` so the whole team gets format-on-save for Terraform files automatically.

---

## Relationship to the Pre-Commit Hook

The pre-commit hook at `scripts/pre-commit-terraform.sh` and these VS Code tasks overlap intentionally:

| Check | Pre-commit Hook | VS Code Task | When to Use |
|---|---|---|---|
| `terraform fmt` | ✅ Blocks commit if fails | ✅ `terraform: fmt (all)` | Task: run interactively; Hook: automatic gate |
| `terraform validate` | ✅ Runs per changed dir | ✅ `terraform: validate` | Same |
| `tflint` | ✅ If installed | Add task | Task: live feedback; Hook: gate |
| `checkov` | ✅ If installed | ✅ Task above | Task: detailed output; Hook: gate |
| `terraform plan` | ❌ Too slow for pre-commit | ✅ Per-workspace tasks | Task only |

The pre-commit hook is a safety net. The VS Code tasks give you faster, interactive feedback while you're writing code.

---

## Related Documents

- [README — Local Development Setup](../../../README.md#local-development)
- [Pre-commit hook script](../../../scripts/pre-commit-terraform.sh)
- [LocalStack Setup Guide](localstack-setup.md)
- [Terraform Best Practices](../to-do/terraform-best-practices.md)
