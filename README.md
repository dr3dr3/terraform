# Terraform Repository

## Quick Start — What Do I Do Here?

This repo manages all AWS infrastructure as code using Terraform. If you're back after a break or onboarding fresh:

- **Adding new infrastructure for a new service?** → See the [New Service Runbook](docs/how-to-guides/new-service-runbook.md)
- **Changing existing infrastructure?** → Edit the relevant folder under `terraform/env-{environment}/{layer}/`, commit to `main`, and Terraform Cloud or GitHub Actions handles the rest (see [CI/CD Pipeline](#cicd-pipeline) below)
- **Not sure which layer or environment?** → See [Layer & Environment Reference](#layer--environment-reference) below
- **Writing or running tests?** → See [`terraform-tests/README.md`](terraform-tests/README.md)
- **Understanding architecture decisions?** → Browse [`docs/reference/architecture-decision-register/`](docs/reference/architecture-decision-register/)

---

## Workflow

Before creating "stacks" under environments and infrastructure layers, start with creating a small composable module.

1. Draft and validate in `/terraform-examples` (`terraform init/plan/apply/destroy`)
2. Write tests for the module in `/terraform-tests` — see [Testing Guide](terraform-tests/README.md)
3. Promote the module to `terraform-modules/` with a version tag (see [ADR-022](docs/reference/architecture-decision-register/ADR-022-module-versioning-strategy.md))
4. Reference the versioned module from the appropriate `terraform/env-{env}/{layer}/` folder
5. Open a PR — Terraform Cloud runs a speculative plan automatically (VCS-driven) or GHA posts a plan comment (API-driven)
6. Merge to `main` — applies per the trigger strategy in [ADR-014](docs/reference/architecture-decision-register/ADR-014-terraform-workspace-triggers.md)

## Local Development

### Setup Steps

#### 1. Configure Environment Variables

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

Then edit `.env` and set at minimum:

| Variable | Required | Description |
|----------|----------|-------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | Yes | 1Password Service Account Token — used by `scripts/inject-tfvars.sh` to inject secrets into `.tfvars` files. Obtain from the [1Password Service Accounts docs](https://developer.1password.com/docs/service-accounts/get-started/). |
| `LAMBDA_EXECUTOR` | No | LocalStack Lambda executor (`docker`/`local`). Defaults to `docker`. |
| `SERVICES` | No | LocalStack services to enable (comma-separated). See `.env.example` for default list. |
| `PERSISTENCE` | No | LocalStack persistence toggle (`0`=off, `1`=on). Defaults to `0`. |

> **Security:** `.env` is git-ignored and must never be committed. Only `.env.example` (with no real secrets) is committed.

Load the variables into your shell session after editing:

- **Fish shell:**

  ```fish
  for line in (grep -v '^#' .env | grep -v '^$')
      set -gx (string split -m 1 '=' $line)
  end
  ```

- **Bash / Zsh:**

  ```bash
  set -a && source .env && set +a
  ```

The `scripts/inject-tfvars.sh` script will also load `.env` automatically if `OP_SERVICE_ACCOUNT_TOKEN` is not already set in your shell environment.

2. **Install 1Password CLI** (for secure secret injection)
   - Download from: [1Password CLI](https://developer.1password.com/docs/cli/get-started/)
   - If using a **Service Account Token** (recommended for automation): no sign-in needed — the CLI authenticates automatically via `OP_SERVICE_ACCOUNT_TOKEN`
   - If using a **personal account**: run `eval $(op signin)`
   - Verify authentication: `op vault list`

3. **Inject Terraform Variables**
   - Run `./scripts/inject-tfvars.sh` to populate `.tfvars` files from `.tfvars.example` templates
   - This uses 1Password to inject secrets without committing them to git
   - See [1Password tfvars injection guide](docs/how-to-guides/1password-tfvars-injection.md) for details

4. **Terraform Cloud Authentication**
   - Run `terraform login` and provide your TF Cloud User Token (under your Account Settings)

5. **Install Pre-Commit Hook** (for Terraform validation)

   ```bash
   cp scripts/pre-commit-terraform.sh .git/hooks/pre-commit
   ```

   This hook runs automatically before each commit and checks:

   - `terraform fmt` - Formatting validation
   - `terraform validate` - Configuration validation
   - `tflint` - Linting (if installed)
   - `checkov` - Security scanning (if installed)

   Only runs on changes to the `terraform/` folder.

## Git Repositories

- [Terraform Repository](https://github.com/dr3dr3/terraform) - Main repository with both Terraform code and documentation
- [Terraform Module Repository](https://github.com/dr3dr3/terraform-modules) - Versioned (via tags) modules used in the above repository

### Folder Structure - Terraform Repository

```markdown
terraform/
├── env-development/
│   ├── applications-layer/
│   │   ├── networking/
│   │   ├── sample-web-app/
│   │   └── eks-learning-cluster/
│   ├── foundation-layer/
│   └── platform-layer/
├── env-staging/
│   ├── applications-layer/
│   ├── foundation-layer/
│   └── platform-layer/
├── env-production/
│   ├── applications-layer/
│   ├── foundation-layer/
│   └── platform-layer/
└── env-management/
    ├── foundation-layer/
    └── platform-layer/
```

### Git Branching

- Trunk-Based Development (commit directly to `main`, use short-lived feature branches for larger changes)

## CI/CD Pipeline

Infrastructure changes flow through two mechanisms depending on the workspace trigger strategy ([ADR-014](docs/reference/architecture-decision-register/ADR-014-terraform-workspace-triggers.md)):

| Mechanism | When Used | Behaviour on PR | Behaviour on Merge to `main` |
|---|---|---|---|
| **VCS-driven (Terraform Cloud)** | Foundation and some platform layers | Speculative plan posted to TFC | Auto or manual apply per workspace config |
| **API/GHA-driven (GitHub Actions)** | EKS platform clusters, application layer | `terraform plan` posted as PR comment | Apply triggered by workflow |

### GitHub Actions Workflows

| Workflow | Trigger | What It Does |
|---|---|---|
| `terraform-dev-platform-eks.yml` | Push/PR to `eks-auto-mode/**`, manual | Plan/apply/destroy EKS in development |
| `terraform-staging-platform-eks.yml` | Push/PR to staging EKS path, manual | Plan/apply/destroy EKS in staging (approval required) |
| `terraform-prod-platform-eks.yml` | Manual only | Plan/apply/destroy EKS in production (approval + confirmation) |
| `reusable-terraform.yml` | Called by other workflows | Generic reusable plan/apply for any workspace |
| `reusable-terraform-eks.yml` | Called by EKS workflows | EKS-specific plan/apply with TTL tagging |
| `eks-ttl-check.yml` | Scheduled (every 6h) | Destroys expired EKS clusters to control cost |
| `eks-drift-detection.yml` | Scheduled | Detects configuration drift |

See [`.github/workflows/README.md`](.github/workflows/README.md) for full details and authentication setup.

## Layer & Environment Reference

### Environments

| Environment | AWS Account | Purpose |
|---|---|---|
| `env-management` | Management | Cross-account IAM, Terraform Cloud config, GitHub config |
| `env-development` | Development | First landing zone — develop and test infra changes here |
| `env-sandbox` | Sandbox | Safe experimentation; automated cleanup protects cost |
| `env-staging` | Staging | Pre-production validation |
| `env-production` | Production | Live workloads; maximum change controls |
| `env-local` | None (LocalStack) | Local development without cloud costs |

### Layers (by change frequency)

| Layer | Change Rate | What Goes Here |
|---|---|---|
| `foundation-layer` | Months | VPCs, IAM, OIDC providers, DNS |
| `platform-layer` | Weeks | EKS clusters, monitoring, logging |
| `applications-layer` | Days | Per-service infra: namespaces, RBAC, HPA, app IAM |
| `sandbox-layer` | Ad-hoc | Experiments and learning |

**When to use which layer:** If the resource would break multiple services if deleted → foundation. If it's shared compute/tooling → platform. If it's specific to one service → applications.

See the full decision rationale in [ADR-003](docs/reference/architecture-decision-register/ADR-003-infra-layering-repository-structure.md).

## Key Documentation

| Document | Purpose |
|---|---|
| [New Service Runbook](docs/how-to-guides/new-service-runbook.md) | Step-by-step guide to provisioning infra for a new service |
| [Testing Guide](terraform-tests/README.md) | How to write and run Terraform tests |
| [ADR Index](docs/reference/adr-index.md) | All architecture decisions |
| [Terraform Code Summary](docs/reference/terraform-code-summary.md) | What's in each workspace today |
| [Bootstrapping Guide](docs/how-to-guides/bootstrapping-guide.md) | First-time account setup |
| [Terraform Best Practices](docs/to-do/terraform-best-practices.md) | Naming, tagging, module patterns |
| [Cross-Stack References](docs/to-do/cross-stack-reference-suggestions.md) | How workspaces share outputs |
| [VS Code Tasks for Terraform](docs/how-to-guides/vscode-tasks-for-terraform.md) | Using VS Code tasks to run Terraform locally |

## Terraform Cloud

### Projects

Terraform Cloud projects map to environment × layer combinations, aligning with the folder structure in this repository.

| Project | Folder |
|---|---|
| `Management - Foundation` | `terraform/env-management/foundation-layer/` |
| `Development - Foundation` | `terraform/env-development/foundation-layer/` |
| `Development - Platform` | `terraform/env-development/platform-layer/` |
| `Development - Applications` | `terraform/env-development/applications-layer/` |
| `Staging - Foundation` | `terraform/env-staging/foundation-layer/` |
| `Staging - Platform` | `terraform/env-staging/platform-layer/` |
| `Production - Foundation` | `terraform/env-production/foundation-layer/` |
| `Production - Platform` | `terraform/env-production/platform-layer/` |
| `Sandbox - Foundation` | `terraform/env-sandbox/foundation-layer/` |
| `Sandbox - Platform` | `terraform/env-sandbox/platform-layer/` |

### Workspace Naming & Trigger Strategy

Workspaces follow the pattern `{environment}-{layer}-{component}`, e.g. `development-platform-eks`.

Each workspace uses one of three trigger mechanisms — see [ADR-014](docs/reference/architecture-decision-register/ADR-014-terraform-workspace-triggers.md) for the full decision. The short version:

- **Foundation workspaces** → CLI-driven (manual `terraform apply`)
- **Platform/Application in dev** → GitHub Actions (GHA workflow triggers apply)
- **Platform/Application in staging/prod** → VCS-driven (Terraform Cloud auto-plans on PR) or GHA with approval gates

See [Terraform Code Summary](docs/reference/terraform-code-summary.md) for the current list of all workspaces, their trigger types, and working directories.
