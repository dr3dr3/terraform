# Architecture Decisions Tracker

> Status of key architectural decisions for our Terraform infrastructure project.

**Last Updated**: December 3, 2025

---

## Quick Summary

| Category | Status | ADRs |
|----------|--------|------|
| Environment Isolation | ✅ Decided | ADR-001, ADR-009, ADR-011 |
| State Management | ✅ Decided | ADR-001 |
| Modularity & Code Structure | ⚠️ Partially Addressed | ADR-003, ADR-009 |
| Security & Authentication | ✅ Decided | ADR-005, ADR-006, ADR-007, ADR-008, ADR-010, ADR-015 |
| Deployment Workflow | ✅ Decided | ADR-002, ADR-014 |
| Automated Testing | 🔴 Needs ADR | - |
| Module Versioning Strategy | 🔴 Needs ADR | - |
| Sandbox Cleanup Automation | ⏳ Proposed | ADR-012 |

---

## Decisions Still Needing Attention

### 🔴 HIGH PRIORITY: Automated Testing Strategy

**Status**: No ADR exists

**What's needed**: An ADR defining our approach to infrastructure testing:

- Static analysis tools (TFLint, Checkov, tfsec)
- Pre-commit hooks configuration
- Unit testing for Terraform modules (using `terraform test` or Terratest)
- Integration testing approach using Sandbox account
- Smoke testing after deployments
- CI/CD pipeline integration for automated testing

**Reference**: See [`docs/explanations/guide-to-testing-terraform.md`](../explanations/guide-to-testing-terraform.md) for comprehensive guidance.

**Recommended ADR scope**:

| Test Type | Tool Options | When to Run |
|-----------|--------------|-------------|
| Static Analysis | `terraform fmt`, `terraform validate`, TFLint | Pre-commit, CI |
| Security Scanning | Checkov, tfsec, Trivy | Pre-commit, CI |
| Policy Enforcement | Sentinel (Terraform Cloud) | CI, pre-apply |
| Unit Testing | Terraform native `test` command | CI |
| Integration Testing | Terratest (Go) in Sandbox account | CI, on merge |
| Smoke Testing | Custom scripts post-apply | Post-deployment |

---

### 🔴 HIGH PRIORITY: Module Versioning Strategy

**Status**: No ADR exists

**Current state**: Reusable modules exist in `terraform-modules/` but lack a versioning strategy:

```text
terraform-modules/
├── permission-set/
└── terraform-oidc-role/
```

**What's needed**: An ADR defining:

- Git tagging convention for module versions (e.g., `module-name/v1.0.0`)
- Semantic versioning rules (when to bump major/minor/patch)
- How environments reference specific module versions
- Module release and promotion process
- Breaking change communication

**Best practice reference**:

```hcl
# Recommended: Pin to specific version
module "oidc_role" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/terraform-oidc-role?ref=terraform-oidc-role/v1.2.0"
}

# NOT recommended: Using main branch
module "oidc_role" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/terraform-oidc-role?ref=main"
}
```

---

### ⏳ PENDING APPROVAL: Sandbox Automated Cleanup (ADR-012)

**Status**: Proposed (not yet Approved)

**Summary**: Defines hybrid approach using Terraform Destroy + AWS Nuke v3 for automated resource cleanup in sandbox environment.

**Action needed**: Review and approve ADR-012 to enable implementation.

---

## Decisions Already Made ✅

### 1. Environment Isolation Strategy

| Decision | Status | ADR |
|----------|--------|-----|
| **Terraform Cloud for state management** | ✅ Approved | [ADR-001](../reference/architecture-decision-register/ADR-001-terraform-state-management.md) |
| **Directory-based environment isolation** | ✅ Approved | [ADR-009](../reference/architecture-decision-register/ADR-009-folder-structure.md) |
| **Sandbox environment for experimentation** | ✅ Approved | [ADR-011](../reference/architecture-decision-register/ADR-011-sandbox-environment.md) |

**Implementation**:

- Separate TFC workspaces per environment/layer (not Terraform workspaces)
- Folder structure: `env-{environment}/{layer}-layer/{stack}/`
- Workspace naming: `{environment}-{layer}-{stack}`
- State isolation via separate TFC workspaces with RBAC

---

### 2. State Management and Security

| Decision | Status | ADR |
|----------|--------|-----|
| **Use Terraform Cloud** (not S3 backend) | ✅ Approved | [ADR-001](../reference/architecture-decision-register/ADR-001-terraform-state-management.md) |

**Key points**:

- ✅ Remote state with automatic locking (built into TFC)
- ✅ Encrypted state storage (managed by TFC)
- ✅ State versioning and rollback (built into TFC)
- ✅ RBAC for production access controls (TFC Teams)
- ✅ Audit logging (TFC audit logs)

---

### 3. Modularity and Code Structure

| Decision | Status | ADR |
|----------|--------|-----|
| **Infrastructure monorepo with layered approach** | ✅ Approved | [ADR-003](../reference/architecture-decision-register/ADR-003-infra-layering-repository-structure.md) |
| **Environments → Layers → Stacks folder pattern** | ✅ Approved | [ADR-009](../reference/architecture-decision-register/ADR-009-folder-structure.md) |
| **Tooling separation (Terraform/Helm/K8s)** | ✅ Approved | [ADR-004](../reference/architecture-decision-register/ADR-004-infra-tooling-separation.md) |

**Implementation**:

- Single repo with `terraform/` directory containing environment folders
- Reusable modules in `terraform-modules/` at repo root
- Layers: Foundation → Platform → Shared Services → Applications
- Cross-layer references via `terraform_remote_state` or `tfe_outputs`

**Gap**: Module versioning strategy not yet defined (see above).

---

### 4. Security and Authentication

| Decision | Status | ADR |
|----------|--------|-----|
| **OIDC authentication** (no static credentials) | ✅ Approved | [ADR-010](../reference/architecture-decision-register/ADR-010-aws-iam-role-structure.md) |
| **Tiered IAM role structure** | ✅ Approved | [ADR-010](../reference/architecture-decision-register/ADR-010-aws-iam-role-structure.md) |
| **AWS Secrets Manager** for secrets | ✅ Approved | [ADR-005](../reference/architecture-decision-register/ADR-005-secrets-manager.md) |
| **Per-environment KMS keys** | ✅ Approved | [ADR-006](../reference/architecture-decision-register/ADR-006-kms-key-management.md) |
| **Environment-scoped IAM policies** | ✅ Approved | [ADR-007](../reference/architecture-decision-register/ADR-007-iam-for-parameter-store.md) |
| **Secret rotation strategies** | ✅ Approved | [ADR-008](../reference/architecture-decision-register/ADR-008-secret-rotation.md) |
| **User personas (AWS SSO + EKS RBAC)** | ✅ Approved | [ADR-015](../reference/architecture-decision-register/ADR-015-user-personas-aws-sso-eks.md) |
| **EKS credentials via 1Password** | ✅ Approved | [ADR-016](../reference/architecture-decision-register/ADR-016-eks-credentials-cross-repo-access.md) |

**Implementation**:

- GitHub Actions uses OIDC federation
- Separate roles: `terraform-{env}-cicd-role` vs `terraform-{env}-human-role`
- IAM Identity Center for human AWS access
- 5-tier persona model (Administrator, Platform Engineer, Namespace Admin, Developer, Auditor)

---

### 5. Deployment Workflow and Automation

| Decision | Status | ADR |
|----------|--------|-----|
| **VCS-driven workflow** (mono-branch + directories) | ✅ Approved | [ADR-002](../reference/architecture-decision-register/ADR-002-terraform-workflow-git-cicd.md) |
| **Tiered trigger strategy** (CLI/VCS/API) | ✅ Approved | [ADR-014](../reference/architecture-decision-register/ADR-014-terraform-workspace-triggers.md) |
| **EKS + 1Password lifecycle coordination** | ✅ Approved | [ADR-017](../reference/architecture-decision-register/ADR-017-eks-1password-lifecycle-coordination.md) |

**Implementation**:

- Main branch with environment directories
- Dev auto-apply, Production manual approval
- Foundation layers: CLI-driven (manual control)
- Application/Platform layers: Mixed VCS/API triggers
- TTL-based auto-destroy for ephemeral resources

**Gap**: Automated testing not yet integrated into CI/CD (see above).

---

## Reference: Best Practices Checklist

Use this checklist when creating new stacks or modules:

### Per-Stack Checklist

- [ ] `backend.tf` with TFC workspace configuration
- [ ] `versions.tf` with pinned Terraform and provider versions
- [ ] `variables.tf` with descriptions and validation rules
- [ ] `outputs.tf` exposing necessary values for downstream stacks
- [ ] `README.md` documenting purpose and usage
- [ ] Required tags defined in `locals.tf`

### Per-Module Checklist

- [ ] Clear `README.md` with examples
- [ ] Input variables with descriptions, types, and defaults
- [ ] Output values for resource attributes
- [ ] No `provider` blocks (provider-agnostic)
- [ ] `examples/` directory with usage examples
- [ ] Version tag applied (once versioning ADR is approved)

---

## Related Documentation

- [ADR Index](../reference/adr-index.md) - Complete list of architecture decisions
- [Terraform Best Practices](./terraform-best-practices.md) - Tactical patterns and conventions
- [Guide to Testing Terraform](../explanations/guide-to-testing-terraform.md) - Comprehensive testing guidance
- [Architecture Principles](../reference/architecture-principles.md) - Guiding principles
