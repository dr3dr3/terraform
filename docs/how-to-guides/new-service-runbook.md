# How to Add Infrastructure for a New Service

> **Audience:** Developers and platform engineers adding AWS infrastructure for a new application service.
>
> **Time:** 1–4 hours depending on complexity.
>
> **Prerequisites:** You have completed the [local development setup](../../../README.md#local-development) and have `terraform login` working.

---

## Overview

Adding infrastructure for a new service involves three phases:

1. **Prototype** — draft and validate the module in `terraform-examples/`
2. **Module** — extract it into a reusable, tested, versioned module in `terraform-modules/`
3. **Deploy** — reference the module from the right environment and layer folders in `terraform/`

Do not skip Phase 1. Prototyping in `terraform-examples/` means mistakes cost nothing.

---

## Phase 1: Prototype in terraform-examples

### Step 1.1 — Create your prototype folder

```bash
mkdir -p terraform-examples/env-local/{your-service-name}
cd terraform-examples/env-local/{your-service-name}
```

Use LocalStack (`env-local`) for the prototype so you don't incur cloud costs.

### Step 1.2 — Write initial Terraform

Create `main.tf`, `variables.tf`, and `outputs.tf`. Use the LocalStack provider config from `terraform-examples/env-local/localstack-provider.tf` as your backend:

```hcl
# main.tf (prototype)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # LocalStack endpoint — copy from terraform-examples/env-local/localstack-provider.tf
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    # add the services you need
  }
}

# Your resources here
resource "aws_s3_bucket" "example" {
  bucket = "my-service-data"
}
```

### Step 1.3 — Validate it works locally

```bash
# Start LocalStack first (see docs/how-to-guides/localstack-setup.md)
docker compose -f docker-compose.localstack.yml up -d

terraform init
terraform plan
terraform apply
terraform destroy   # clean up
```

**Do not proceed to Phase 2 until `apply` and `destroy` both succeed without errors.**

---

## Phase 2: Create a Reusable Module

### Step 2.1 — Create the module folder

```bash
mkdir -p terraform-modules/{your-module-name}
cd terraform-modules/{your-module-name}
```

Use kebab-case naming. Match the name to what the module does, not the service that first needs it (modules should be reusable):

- Good: `terraform-modules/s3-data-bucket/`
- Bad: `terraform-modules/my-service-stuff/`

### Step 2.2 — Standard module file structure

Every module must contain:

```text
terraform-modules/{module-name}/
├── main.tf          ← resources
├── variables.tf     ← all input variables with descriptions and types
├── outputs.tf       ← all outputs (everything a consumer might need)
├── versions.tf      ← required_providers and version constraints
└── examples/
    └── basic/
        ├── main.tf  ← minimal working example
        └── README.md
```

**variables.tf** — always include `description`, `type`, and `default` (where safe):

```hcl
variable "environment" {
  description = "Environment name (development, staging, production, sandbox)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production", "sandbox"], var.environment)
    error_message = "environment must be one of: development, staging, production, sandbox"
  }
}

variable "name" {
  description = "Resource name. Will be prefixed with the environment."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
```

**outputs.tf** — expose everything a consumer might need downstream:

```hcl
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket
}
```

### Step 2.3 — Apply standard tagging

All resources must use the standard tag set. Add a `locals.tf`:

```hcl
locals {
  standard_tags = merge(
    {
      Environment = title(var.environment)
      ManagedBy   = "Terraform"
      Module      = "{your-module-name}"
    },
    var.tags
  )
}

# Then on every resource:
resource "aws_s3_bucket" "this" {
  bucket = "${var.environment}-${var.name}"
  tags   = local.standard_tags
}
```

See [AWS Tagging Strategy](../reference/aws-tagging-strategy.md) for the full required tag set.

### Step 2.4 — Write tests

Add a `tests/` folder inside the module with at minimum a basic test:

```hcl
# terraform-modules/{module-name}/tests/basic.tftest.hcl

run "creates_with_defaults" {
  command = apply

  variables {
    environment = "sandbox"
    name        = "test"
  }

  assert {
    condition     = output.bucket_arn != ""
    error_message = "Expected a non-empty bucket ARN"
  }
}
```

Run the tests:

```bash
cd terraform-modules/{module-name}
terraform test
```

Also add a Terratest integration test in `terraform-tests/modules/{module-name}/`. See [terraform-tests/README.md](../../../terraform-tests/README.md) for the full guide.

### Step 2.5 — Version and tag the module

Once the module is merged to `main` and tests pass, tag it:

```bash
git tag {module-name}/v1.0.0
git push origin {module-name}/v1.0.0
```

See [ADR-022: Module Versioning Strategy](../reference/architecture-decision-register/ADR-022-module-versioning-strategy.md) for the full versioning convention.

---

## Phase 3: Deploy to Environments

### Step 3.1 — Decide which layer and environment

Use the decision table:

| Ask yourself | If yes → |
|---|---|
| Would deleting this resource break multiple services? | `foundation-layer` |
| Is this shared compute or tooling (e.g. EKS, monitoring)? | `platform-layer` |
| Is this specific to one service (IAM role, namespace, HPA)? | `applications-layer` |
| Is this experimental or temporary? | `sandbox-layer` |

Start with `env-development` first. Never create new infra directly in staging or production.

### Step 3.2 — Create the environment folder

```bash
mkdir -p terraform/env-development/applications-layer/{your-service-name}
cd terraform/env-development/applications-layer/{your-service-name}
```

### Step 3.3 — Write the environment configuration

```hcl
# main.tf

terraform {
  required_version = "~> 1.14.0"

  cloud {
    organization = "Datafaced"
    workspaces {
      name = "development-applications-{your-service-name}"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Read outputs from the foundation layer (VPC, IAM, etc.)
data "tfe_outputs" "foundation" {
  organization = "Datafaced"
  workspace    = "development-foundation-iam-roles-for-terraform"
}

# Reference your versioned module
module "my_service" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/{your-module-name}?ref={module-name}/v1.0.0"

  environment = "development"
  name        = "my-service"

  # Use outputs from the foundation layer instead of hardcoding
  # vpc_id = data.tfe_outputs.foundation.values.vpc_id
}
```

```hcl
# variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}
```

```hcl
# outputs.tf
# Export anything that other stacks might need
output "service_role_arn" {
  description = "IAM role ARN for the service"
  value       = module.my_service.role_arn
}
```

```hcl
# backend.tf  (keep backend config separate)
# Already handled by the cloud{} block in main.tf for TFC.
# If using local state for env-local, put the backend block here.
```

### Step 3.4 — Create the Terraform Cloud workspace

If the workspace doesn't exist yet:

1. Check `terraform/env-management/foundation-layer/terraform-cloud/workspaces.tf` — this is where all workspaces are defined
2. Add a new `tfe_workspace` resource following the existing patterns
3. Add `tfe_variable` resources for `TFC_AWS_PROVIDER_AUTH` and `TFC_AWS_RUN_ROLE_ARN`
4. Apply the `management-foundation-terraform-cloud` workspace to create it

```bash
cd terraform/env-management/foundation-layer/terraform-cloud
terraform plan   # review the new workspace resource
terraform apply
```

### Step 3.5 — Open a PR

```bash
git checkout -b add-{service-name}-infra
git add terraform/ terraform-modules/
git commit -m "feat: add infra for {service-name} in development applications layer"
git push origin add-{service-name}-infra
```

If the workspace is GHA-driven, a `terraform plan` will be posted as a PR comment automatically. If it's VCS-driven, check Terraform Cloud for the speculative plan.

Review the plan output carefully before merging. Key things to check:

- [ ] Only the expected resources are being created
- [ ] No resources are being unexpectedly destroyed
- [ ] Tag values look correct
- [ ] Sensitive outputs are marked sensitive

### Step 3.6 — Merge and verify

Merge to `main`. Depending on the workspace trigger type:

- **VCS-driven**: Terraform Cloud applies automatically (or awaits manual confirm if `auto_apply = false`)
- **GHA-driven**: The GHA workflow applies on merge to `main`
- **CLI-driven** (foundation): You must run `terraform apply` manually

After apply, verify the resources exist in AWS:

```bash
aws --profile development {service} describe...
```

### Step 3.7 — Promote to staging and production

Once validated in development:

1. Create the same folder structure under `env-staging/` and `env-production/`
2. Create corresponding workspaces in `workspaces.tf`
3. Open a PR for staging, get approval, apply
4. Repeat for production (additional approval gates apply)

---

## Checklist Summary

### New Module Checklist

- [ ] Prototype works in `terraform-examples/` (plan + apply + destroy)
- [ ] Module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] All variables have `description` and `type`
- [ ] All resources use standard tags via `local.standard_tags`
- [ ] `terraform validate` passes
- [ ] `tflint` passes (no warnings)
- [ ] `checkov` passes (no HIGH/CRITICAL findings, or findings are documented)
- [ ] Native tests in `tests/*.tftest.hcl` pass (`terraform test`)
- [ ] Module tagged with `{name}/v1.0.0`

### New Environment Stack Checklist

- [ ] Correct layer chosen (foundation / platform / applications)
- [ ] Start in `env-development` — never start in staging/prod
- [ ] Module referenced with explicit version tag (`?ref=...`)
- [ ] Cross-stack references using `data "tfe_outputs"` (not hardcoded ARNs/IDs)
- [ ] Outputs defined for anything downstream stacks might need
- [ ] Terraform Cloud workspace created in `workspaces.tf`
- [ ] PR plan reviewed — no unexpected destroys
- [ ] Applied and verified in development before promotion

---

## Common Mistakes

| Mistake | Why It's a Problem | Fix |
|---|---|---|
| Starting in `env-production` | No safety net if the plan is wrong | Always start in `env-development` |
| Hardcoding account IDs or role ARNs | Breaks when accounts change, hard to audit | Use `data "tfe_outputs"` from the workspace that creates those resources |
| Using `?ref=main` instead of a version tag | A future module change silently breaks your stack | Always pin to a tag: `?ref=module-name/v1.0.0` |
| No outputs defined | Downstream stacks can't reference your resources | Add all meaningful outputs to `outputs.tf` |
| Missing `terraform destroy` in prototype | Leaves orphaned LocalStack resources | Always test destroy before promoting |
| No tests | Regressions are caught in production | Follow the testing guide |

---

## Related Documents

- [README — Layer & Environment Reference](../../../README.md#layer--environment-reference)
- [Testing Guide](../../../terraform-tests/README.md)
- [ADR-022: Module Versioning Strategy](../reference/architecture-decision-register/ADR-022-module-versioning-strategy.md)
- [ADR-003: Infra Layering & Repository Structure](../reference/architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
- [ADR-014: Workspace Trigger Strategy](../reference/architecture-decision-register/ADR-014-terraform-workspace-triggers.md)
- [Cross-Stack Reference Suggestions](../to-do/cross-stack-reference-suggestions.md)
- [Terraform Best Practices](../to-do/terraform-best-practices.md)
- [LocalStack Setup](localstack-setup.md)
