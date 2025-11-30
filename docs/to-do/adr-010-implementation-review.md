# ADR-010 Implementation Review: AWS IAM Role Structure

**Review Date:** 2025-11-29

**ADR Reviewed:** ADR-010-aws-iam-role-structure.md

---

## Executive Summary

This document captures the findings from reviewing the current Terraform codebase against ADR-010 (AWS IAM Role Structure for Terraform OIDC Authentication). The implementation is partially complete, with development environment well-structured but gaps in other environments and missing human roles.

---

## ✅ What's Well Aligned

### 1. Environment-Based Role Separation (ADR Requirement: Mandatory)

Current code correctly implements environment separation:

- `terraform/env-development/foundation-layer/iam-roles-for-terraform/` - Development account roles
- `terraform/env-management/foundation-layer/terraform-cloud-oidc-role/` - Management account bootstrap role
- Workspaces defined for staging and sandbox in `workspaces.tf`

### 2. Execution Context Split (ADR Recommendation: Human vs CICD)

Partially implemented:

- CICD roles are created: `terraform-dev-foundation-cicd-role`, `terraform-dev-platform-cicd-role`, `terraform-dev-applications-cicd-role`
- Role naming follows the pattern: `terraform-{env}-{layer}-{context}-role`

### 3. Layer-Based Roles (ADR: Optional for Mature Orgs)

**Fully implemented in development!** The `env-development/foundation-layer/iam-roles-for-terraform/main.tf` creates:

- `terraform-dev-foundation-cicd-role`
- `terraform-dev-platform-cicd-role`
- `terraform-dev-applications-cicd-role`

This aligns with ADR's Phase 3 structure for layer-based subdivision.

### 4. Trust Policy Requirements

✅ Correct OIDC conditions with:

- `StringEquals` for audience validation
- `StringLike` for subject claims scoped to organization/project/workspace

### 5. Session Duration

Roles use `max_session_duration = 7200` (2 hours) - matches ADR's production recommendation. Dev environments could potentially be longer (4-12 hours) per ADR.

### 6. Tagging Strategy

Excellent compliance! Roles include:

- `Environment`, `Layer`, `Context`, `Name`, `Owner`
- Missing: `ManagedBy` (present in some, not all), `Purpose` tag consistency

### 7. IAM Identity Center Separation

`iam-roles-for-people/main.tf` correctly separates human console access via Permission Sets from Terraform OIDC roles - exactly as ADR recommends.

---

## ⚠️ Gaps & Missing Items

### 1. Missing Human Roles (-human-role)

**ADR Requires:** Separate roles for `terraform-{env}-{layer}-human-role`

**Current State:** Only CICD roles exist (`-cicd-role`). No human roles for developer terminal usage.

**Impact:** Developers cannot run Terraform locally with appropriate OIDC authentication. The management account's `terraform-cloud-oidc-role` has a wildcard subject (`workspace:*`) which is too permissive.

### 2. Missing Staging & Production Roles

**ADR Requires:** Roles for all environments (dev, staging, production)

**Current State:**

- ✅ Development: `env-development/foundation-layer/iam-roles-for-terraform/` exists
- ❌ Staging: Only workspace defined, no actual role code
- ❌ Production: No role code found
- ❌ Sandbox: Only workspace defined, no actual role code

The `workspaces.tf` references paths like `terraform/env-staging/foundation-layer/iam-roles-for-terraform` but those directories don't exist.

### 3. No Permission Boundaries

**ADR Recommends:** "Permission Boundaries: Enforce maximum permission ceiling across all roles"

**Current State:** The module `terraform-oidc-role` has `permission_boundary_arn` variable but it's not being used in `env-development/foundation-layer/iam-roles-for-terraform/main.tf`.

### 4. Bootstrap Role Too Permissive

**ADR Risk:** "Over-permissive role in production"

**Current State:** `terraform-cloud-oidc-role` in management account:

```hcl
StringLike = {
  "${local.tfc_hostname}:sub" = "organization:${local.tfc_organization}:project:*:workspace:*:run_phase:*"
}
```

This allows **any** workspace in the organization to assume this role.

**Recommendation:** Scope to specific projects or use separate roles per environment.

### 5. Inconsistent Use of Reusable Module

You have a well-designed module at `terraform-modules/terraform-oidc-role/` but:

- `env-development/foundation-layer/iam-roles-for-terraform/main.tf` creates roles **inline** instead of using the module
- This leads to code duplication as you scale to staging/production

### 6. GitHub Actions Roles in Wrong Account

**Potential Issue:** `env-management/foundation-layer/github-actions-oidc-role/` creates a role named `github-actions-dev-platform` in the **management** account, but the comments say it's for development EKS.

The development account version in `env-development/foundation-layer/github-actions-oidc-role/` is correct - OIDC provider must be in the target account.

### 7. Missing CloudTrail Monitoring/Alerting

**ADR Requires:** "Enable CloudTrail logging for all AssumeRole events" and "Implement alerts for production role usage outside expected patterns"

**Current State:** No CloudTrail or alerting configuration found in terraform code.

---

## 📋 Summary Table

| ADR Requirement | Status | Notes |
|-----------------|--------|-------|
| Environment-based roles (dev/staging/prod) | ⚠️ Partial | Only dev implemented, others missing |
| Execution context split (cicd/human) | ⚠️ Partial | Only CICD roles exist |
| Layer-based subdivision | ✅ Good | Implemented for dev environment |
| Trust policy conditions | ✅ Good | Correct OIDC conditions |
| Session duration guidelines | ⚠️ | 2hr for all; dev could be longer |
| Permission boundaries | ❌ Missing | Variable exists but not used |
| Tagging compliance | ✅ Good | Most tags present |
| IAM Identity Center separation | ✅ Good | Properly separated |
| CloudTrail monitoring | ❌ Missing | No audit infrastructure |
| Documentation/helper scripts | ❌ Missing | ADR mentions developer guides |

---

## 🔧 Recommended Actions

### Priority 1: Create missing environment roles

- Copy `env-development/foundation-layer/iam-roles-for-terraform/` to staging, sandbox, and production
- Adjust permissions (production should be more restrictive)

### Priority 2: Add human roles

- Create `terraform-{env}-{layer}-human-role` for each layer
- Use IdP group claims for trust policy conditions

### Priority 3: Use the reusable module

- Refactor `env-development/foundation-layer/iam-roles-for-terraform/` to use `terraform-modules/terraform-oidc-role/`
- This ensures consistency across environments

### Priority 4: Implement permission boundaries

- Create a permission boundary policy that caps maximum permissions
- Attach to all terraform roles

### Priority 5: Tighten bootstrap role

- Scope `terraform-cloud-oidc-role` to specific projects instead of wildcards
- Or create separate management-account roles per use case

### Priority 6: Add audit infrastructure

- CloudTrail configuration for `AssumeRole` events
- CloudWatch alarms for unexpected role assumptions

### Priority 7: Cleanup duplicate GitHub Actions code

- Delete `env-management/foundation-layer/github-actions-oidc-role/` (creates dev role in wrong account)
- Keep only `env-development/foundation-layer/github-actions-oidc-role/`

---

## 📈 ADR Implementation Phase Assessment

Based on current code, implementation is between **Phase 1 and Phase 3**:

- Jumped to Phase 3 (layer-based) for development
- Haven't completed Phase 1 (all environments) for staging/production
- Missing Phase 2 (human/cicd split) everywhere

**Recommendation:** Complete Phase 1 for all environments first, then add human roles (Phase 2) before expanding layer-based roles (Phase 3) to other environments.

---

## Next Steps

1. [ ] Create staging IAM roles (`env-staging/foundation-layer/iam-roles-for-terraform/`)
2. [ ] Create sandbox IAM roles (`env-sandbox/foundation-layer/iam-roles-for-terraform/`)
3. [ ] Create production IAM roles (`env-production/foundation-layer/iam-roles-for-terraform/`)
4. [ ] Add human roles for development environment
5. [ ] Refactor to use `terraform-modules/terraform-oidc-role/` module
6. [ ] Implement permission boundaries
7. [ ] Tighten management account bootstrap role
8. [ ] Add CloudTrail monitoring terraform code
9. [ ] Remove duplicate GitHub Actions role from management account
10. [ ] Create developer documentation for role usage
