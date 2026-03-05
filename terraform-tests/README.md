# Terraform Tests

This folder contains tests for Terraform modules and configurations in this repository.

> **Why test Terraform?** Infrastructure bugs don't fail at compile time — they fail in production. Tests catch regressions, validate module contracts, and give you confidence when refactoring. They also serve as living documentation of how modules are expected to behave.

---

## Folder Structure

```text
terraform-tests/
├── README.md                        ← You are here
├── modules/
│   ├── permission-set/
│   │   └── permission_set_test.go   ← Terratest unit test
│   └── terraform-oidc-role/
│       └── oidc_role_test.go
└── integration/
    └── sandbox/
        └── eks_integration_test.go  ← Integration test using sandbox account
```

Each module under `terraform-modules/` should have a corresponding test folder here.

---

## Testing Approach

We use a layered testing strategy. Run cheaper/faster tests first; escalate to slower/costlier tests only when needed.

### Layer 1 — Static Analysis (runs locally + on every PR)

These run in seconds and require no AWS credentials.

| Tool | What It Checks | How to Run |
|---|---|---|
| `terraform fmt -check` | Code formatting | `terraform fmt -check -recursive` |
| `terraform validate` | Syntax and provider schema | `cd <module> && terraform validate` |
| `tflint` | Best-practice linting | `tflint --recursive` |
| `checkov` | Security misconfigurations | `checkov -d terraform/` |

The pre-commit hook at `scripts/pre-commit-terraform.sh` runs all of these automatically. Install it once:

```bash
cp scripts/pre-commit-terraform.sh .git/hooks/pre-commit
```

### Layer 2 — Native Terraform Tests (runs in CI, real AWS)

Terraform's built-in `terraform test` command (available since v1.6) lets you write declarative tests in `.tftest.hcl` files alongside your module.

**When to use:** Validating module outputs, defaults, variable validation rules, and simple resource configurations.

**Example** — testing the `permission-set` module:

```hcl
# terraform-modules/permission-set/tests/defaults.tftest.hcl

run "creates_permission_set_with_defaults" {
  command = apply

  variables {
    name             = "test-permission-set"
    description      = "Test"
    session_duration = "PT1H"
  }

  assert {
    condition     = aws_ssoadmin_permission_set.this.name == "test-permission-set"
    error_message = "Permission set name did not match expected value"
  }

  assert {
    condition     = aws_ssoadmin_permission_set.this.session_duration == "PT1H"
    error_message = "Session duration did not match expected value"
  }
}
```

Run a module's tests:

```bash
cd terraform-modules/permission-set
terraform test
```

### Layer 3 — Terratest Integration Tests (runs against Sandbox account)

[Terratest](https://terratest.gruntwork.io/) is a Go testing library that applies real Terraform, makes assertions against real AWS resources, then destroys everything. Use it for end-to-end validation of complex modules (e.g. EKS, VPC, IAM OIDC).

**When to use:** Validating that resources actually exist and behave correctly in AWS after apply. Use the Sandbox environment to keep costs isolated.

**Prerequisites:**

```bash
# Install Go
brew install go  # or apt install golang

# Install test dependencies
cd terraform-tests/modules/<module>
go mod tidy
```

**Example test structure:**

```go
// terraform-tests/modules/terraform-oidc-role/oidc_role_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestOidcRoleCreation(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../../../terraform-modules/terraform-oidc-role",
        Vars: map[string]interface{}{
            "role_name": "test-oidc-role",
            "environment": "sandbox",
        },
    }

    // Destroy at end of test
    defer terraform.Destroy(t, opts)

    terraform.InitAndApply(t, opts)

    roleArn := terraform.Output(t, opts, "role_arn")
    assert.Contains(t, roleArn, "arn:aws:iam::")
}
```

Run integration tests:

```bash
cd terraform-tests/modules/terraform-oidc-role
AWS_PROFILE=sandbox go test -v -timeout 30m
```

---

## What to Test Per Module

When creating a new module under `terraform-modules/`, write tests that cover:

| Test Scenario | Recommended Tool |
|---|---|
| Variable validation rules reject bad input | `terraform test` |
| Defaults produce the expected resource config | `terraform test` |
| Module outputs contain expected values | `terraform test` or Terratest |
| Module creates real resources correctly in AWS | Terratest (Sandbox) |
| Module cleans up (destroy works without errors) | Terratest (Sandbox) |
| Security: no public buckets, no unencrypted storage | `checkov` |

---

## CI Integration

Tests run automatically via GitHub Actions on every PR that modifies `terraform-modules/**` or `terraform/**`.

> **Note:** The CI pipeline for module tests is tracked in [`docs/to-do/architecture-decisions-needed.md`](../docs/to-do/architecture-decisions-needed.md) under the high-priority "Automated Testing Strategy" ADR item.

Planned CI stages:

```text
PR opened / pushed
├── Layer 1: fmt + validate + tflint + checkov (always, fast)
├── Layer 2: terraform test (on module changes)
└── Layer 3: Terratest integration (on merge to main, Sandbox account)
```

---

## Adding Tests for a New Module

1. Create the module under `terraform-modules/{module-name}/`
2. Add a `tests/` folder inside the module with `.tftest.hcl` files for native tests
3. Add a Terratest folder under `terraform-tests/modules/{module-name}/` for integration tests
4. Run `terraform test` locally before opening a PR

---

## Costs & Safety

- All integration tests run in the **Sandbox AWS account** only
- Terratest always calls `defer terraform.Destroy(...)` to clean up, even on test failure
- The Sandbox automated cleanup (ADR-012) provides a backstop if tests fail to clean up
- Foundation-layer tests must never run against development, staging, or production accounts

---

## Related Documents

- [Testing Explanation](../docs/explanations/guide-to-testing-terraform.md) — deeper conceptual guide
- [ADR: Automated Testing Strategy](../docs/to-do/architecture-decisions-needed.md) — pending ADR
- [ADR-011: Sandbox Environment](../docs/reference/architecture-decision-register/ADR-011-sandbox-environment.md) — why the sandbox exists
- [ADR-012: Sandbox Cleanup](../docs/reference/architecture-decision-register/ADR-012-sandbox-automated-cleanup.md) — automated cleanup
