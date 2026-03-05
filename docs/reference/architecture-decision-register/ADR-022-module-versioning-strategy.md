# ADR-022: Module Versioning Strategy

| Field | Value |
|---|---|
| **Status** | Draft |
| **Date** | March 2026 |
| **Decision Makers** | Platform Engineering Team |
| **Scope** | All reusable modules in `terraform-modules/` and the external `terraform-modules` repository |

---

## Context

Reusable Terraform modules live in two places:

1. **This repository** (`terraform-modules/`) — modules co-located with the infrastructure that uses them
2. **External module repository** (`github.com/dr3dr3/terraform-modules`) — separately versioned modules intended for cross-repository sharing

Currently neither location has a versioning strategy. All module consumers implicitly reference the `main` branch:

```hcl
# What is currently happening (implicit, undocumented)
module "oidc_role" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/terraform-oidc-role"
}
```

This is unsafe because:

- A breaking change to a module immediately affects every environment that uses it
- There is no way to test a module change in development before it affects production
- Rollback requires reverting git history rather than pinning to a previous version
- It is impossible to tell which version of a module an environment is using without reading the full git log

### Current Modules

```text
terraform-modules/
├── permission-set/         # AWS IAM Identity Center permission sets
└── terraform-oidc-role/    # OIDC IAM role for Terraform Cloud
```

---

## Decision Drivers

- **Safety**: Breaking changes to modules should not automatically affect all environments
- **Progressive rollout**: New module versions should be tested in development before staging/production
- **Simplicity**: The versioning mechanism should be easy to understand and operate
- **Traceability**: It must be obvious which module version is deployed in which environment
- **Minimal overhead**: The process should not require a full release pipeline for small changes

---

## Options Considered

### Option A: Git Tags (Recommended)

Tag the repository at a commit with a module-namespaced tag, e.g. `terraform-oidc-role/v1.2.0`. Consumers reference the tag via the `?ref=` parameter.

```hcl
module "oidc_role" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/terraform-oidc-role?ref=terraform-oidc-role/v1.2.0"
}
```

Pros:

- Native git feature, no extra tooling
- Tags are immutable — pinned consumers never change unexpectedly
- Easy to see what's deployed: read the `source` line
- Works identically for both the monorepo and the external module repo

Cons:

- Must create and push a tag manually (or via CI) for each module release
- Tags accumulate over time (manageable, but requires discipline)

### Option B: GitHub Releases with Terraform Registry

Publish modules to the Terraform Registry (public or private via TFC). Consumers use `registry.terraform.io` source.

Pros: Standard versioning UI, automatic changelog

Cons: Requires a separate module registry, no longer ties to this repo, adds complexity not warranted for our scale.

### Option C: Directory Pinning with Git Hash

Pin to a specific commit SHA:

```hcl
source = "git::...?ref=a3f8bc2"
```

Pros: Maximally precise

Cons: Unreadable, no semantic meaning, hard to find the right hash

---

## Decision

**Option A: Git tag-based versioning using module-namespaced tags.**

This provides the best balance of safety, simplicity, and traceability for the current team size and codebase.

---

## Versioning Convention

### Tag Format

```text
{module-name}/v{major}.{minor}.{patch}
```

Examples:

```text
terraform-oidc-role/v1.0.0
terraform-oidc-role/v1.1.0
terraform-oidc-role/v2.0.0
permission-set/v1.0.0
permission-set/v1.0.1
```

### Semantic Versioning Rules

| Version Bump | When to Use | Example |
|---|---|---|
| **Patch** (`v1.0.x`) | Bug fix, no interface change | Fix a typo in a tag value |
| **Minor** (`v1.x.0`) | New optional variable or output added (backwards compatible) | Add optional `tags` variable with a default |
| **Major** (`vx.0.0`) | Removed variable, renamed output, changed required inputs (breaking) | Rename `role_name` to `name` |

> **Rule of thumb:** If existing consumers need to change their code to upgrade, it's a major version bump.

---

## Module Release Process

### Creating a New Module Version

1. Make and review changes to the module in a PR
2. Merge to `main`
3. Create and push the tag:

   ```bash
   git tag terraform-oidc-role/v1.2.0
   git push origin terraform-oidc-role/v1.2.0
   ```

4. Update the consuming workspace(s) in `terraform/env-development/` first
5. Open a PR with the version bump, verify the plan looks correct
6. Merge and apply to development
7. Once validated, bump the version in staging, then production

### Promoting a Module Version Across Environments

```text
terraform-modules/ (change)
    ↓ tag: module-name/v1.2.0
env-development (bump version, apply, validate)
    ↓ once stable
env-staging (bump version, apply, validate)
    ↓ once stable
env-production (bump version, apply with approval)
```

Never skip development when promoting a breaking change.

---

## Source Reference Formats

### Internal Module (same repo)

```hcl
module "oidc_role" {
  source = "git::https://github.com/dr3dr3/terraform.git//terraform-modules/terraform-oidc-role?ref=terraform-oidc-role/v1.2.0"
}
```

### External Module Repo

```hcl
module "some_module" {
  source = "git::https://github.com/dr3dr3/terraform-modules.git//some-module?ref=some-module/v2.0.0"
}
```

> **Never use `?ref=main`** in any environment folder under `terraform/`. Only use it in `terraform-examples/` for prototyping.

---

## Implementation Plan

### Phase 1 — Existing Modules (Week 1)

- [ ] Tag `terraform-modules/permission-set` at its current state as `permission-set/v1.0.0`
- [ ] Tag `terraform-modules/terraform-oidc-role` at its current state as `terraform-oidc-role/v1.0.0`
- [ ] Update all existing consumers in `terraform/` to use explicit `?ref=` tags
- [ ] Add a linting check (or pre-commit hook) that rejects `?ref=main` in `terraform/` folders

### Phase 2 — Process Documentation (Week 1-2)

- [ ] Add a `CHANGELOG.md` to each module folder
- [ ] Document the release process in a how-to guide
- [ ] Add module versioning check to the pre-commit hook

### Phase 3 — CI Automation (Future)

- [ ] GitHub Actions workflow to validate that `?ref=main` is not used in `terraform/` on PRs
- [ ] Automated tag creation on merge to `main` when module files change (optional)

---

## Consequences

**Positive:**

- Breaking module changes no longer immediately affect production
- Clear audit trail: the source line tells you exactly which version is deployed
- Environments can be on different module versions during rollout

**Negative:**

- Module upgrades require explicit PRs per environment (slightly more work, but safer)
- Tags accumulate in the repository (use `git tag -l "module-name/*"` to list)
- Initial setup requires tagging all existing modules and updating all consumers

---

## Related Documents

- [terraform-tests/README.md](../../../terraform-tests/README.md) — testing modules before releasing
- [ADR-003: Infra Layering](ADR-003-infra-layering-repository-structure.md)
- [ADR-009: Folder Structure](ADR-009-folder-structure.md)
- [Terraform Best Practices](../../to-do/terraform-best-practices.md)
