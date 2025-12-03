# ADR-010 Implementation Review: AWS IAM Role Structure

**Review Date:** 2025-12-03

**ADR Reviewed:** ADR-010-aws-iam-role-structure.md

---

## Executive Summary

This document captures the findings from reviewing the current Terraform codebase against ADR-010 (AWS IAM Role Structure for Terraform OIDC Authentication). The implementation has progressed significantly since the last review, with comprehensive IAM Identity Center setup and EKS cluster admin functionality now in place. Development environment is well-structured, but gaps remain in staging/sandbox environments and human roles.

---

## ✅ What's Well Aligned

### 1. Environment-Based Role Separation (ADR Requirement: Mandatory)

Current code correctly implements environment separation:

- `terraform/env-development/foundation-layer/iam-roles-for-terraform/` - Development account roles ✅
- `terraform/env-management/foundation-layer/tfc-oidc-role/` - Management account bootstrap role ✅
- Workspaces defined for staging and sandbox in `workspaces.tf` (code folders pending)

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

### 7. IAM Identity Center Separation (NEW - Fully Implemented!)

`env-management/foundation-layer/iam-roles-for-people/main.tf` now provides comprehensive IAM Identity Center management:

**Users:**

- `andre.dreyer` user with full identity details

**Groups (per ADR-015 User Personas):**

- `Administrators` - Full access to all AWS services
- `Platform-Engineers` - EKS/Infrastructure management (maps to K8s cluster-admin)
- `Namespace-Admins` - Namespace-scoped control
- `Developers` - Application deployment focus
- `Auditors` - Read-only compliance access

**Permission Sets:**

- `AdministratorAccess` (existing, referenced via data source)
- `PlatformEngineerAccess` - 8hr session, EKS/VPC management
- `NamespaceAdminAccess` - 8hr session, EKS describe + ECR
- `DeveloperAccess` - 12hr session, EKS describe + ECR + CloudWatch
- `AuditorAccess` - 12hr session, ReadOnlyAccess + Cost Explorer

**Account Assignments:**

- Administrators → All accounts
- Platform Engineers → All accounts
- Namespace Admins → Non-production accounts only
- Developers → Non-production accounts only
- Auditors → All accounts (compliance access)

This excellently separates human console access via Permission Sets from Terraform OIDC roles - exactly as ADR recommends.

### 8. EKS Cluster Admin (NEW - Implemented!)

`env-management/foundation-layer/eks-cluster-admin/main.tf` provides:

- 1Password integration for EKS cluster connection details
- Stores cluster name, endpoint, region, ARN, OIDC provider URL
- Supports dev, staging, production, and sandbox environments
- Uses TFC outputs to read EKS cluster state
- Per ADR-016: Phase 1.2 Terraform to 1Password Integration

### 9. GitHub Actions OIDC (Dual Implementation - Corrected!)

GitHub Actions OIDC roles are now correctly implemented in both accounts:

- `env-management/foundation-layer/gha-oidc/` - Management account (workspace: `management-github-actions-oidc`)
- `env-development/foundation-layer/gha-oidc/` - Development account (workspace: `development-foundation-gha-oidc`)

Both create:

- GitHub Actions OIDC provider
- `github-actions-dev-platform` IAM role
- Trust policy scoped to specific GitHub repo

---

## ⚠️ Gaps & Missing Items

### 1. Missing Human Roles (-human-role)

**ADR Requires:** Separate roles for `terraform-{env}-{layer}-human-role`

**Current State:** Only CICD roles exist (`-cicd-role`). No human roles for developer terminal usage.

**Impact:** Developers cannot run Terraform locally with appropriate OIDC authentication. However, the IAM Identity Center permission sets now provide console access for human users, which partially addresses this.

**Note:** The management account's `terraform-cloud-oidc-role` trust policy allows human role patterns:

```hcl
"arn:aws:iam::*:role/terraform-*-*-human-role"
```

### 2. Missing Staging, Sandbox & Production Roles

**ADR Requires:** Roles for all environments (dev, staging, production, sandbox)

**Current State:**

- ✅ Development: `env-development/foundation-layer/iam-roles-for-terraform/` exists with OIDC provider and layer roles
- ❌ Staging: Workspace defined (`staging-foundation-iam-roles`), code folder missing
- ❌ Sandbox: Workspace defined (`sandbox-foundation-iam-roles`), code folder missing
- ❌ Production: No workspace or role code found

The `workspaces.tf` references paths like `terraform/env-staging/foundation-layer/iam-roles-for-terraform` but those directories don't exist yet.

### 3. No Permission Boundaries

**ADR Recommends:** "Permission Boundaries: Enforce maximum permission ceiling across all roles"

**Current State:** The module `terraform-oidc-role` has `permission_boundary_arn` variable but it's not being used in `env-development/foundation-layer/iam-roles-for-terraform/main.tf`.

### 4. Bootstrap Role Scope (Improved but still broad)

**ADR Risk:** "Over-permissive role in production"

**Current State:** `terraform-cloud-oidc-role` in management account:

```hcl
StringLike = {
  "${local.tfc_hostname}:sub" = "organization:${local.tfc_organization}:project:*:workspace:*:run_phase:*"
}
```

This allows **any** workspace in the organization to assume this role. However, the role's IAM policy is now more appropriately scoped to:

- IAM Identity Center operations (identitystore, sso, ssoadmin)
- OIDC provider management
- Terraform-specific IAM roles only (`terraform-*`, `github-actions-*`)

**Recommendation:** Consider scoping to specific projects or create separate roles per environment.

### 5. Inconsistent Use of Reusable Module

You have a well-designed module at `terraform-modules/terraform-oidc-role/` but:

- `env-development/foundation-layer/iam-roles-for-terraform/main.tf` creates roles **inline** instead of using the module
- This leads to code duplication as you scale to staging/production

### 6. ~~GitHub Actions Roles in Wrong Account~~ (RESOLVED)

**Previous Issue:** `env-management/foundation-layer/github-actions-oidc-role/` created a role in the wrong account.

**Current State:** Both accounts now have their own GitHub Actions OIDC setup:

- `env-management/foundation-layer/gha-oidc/` → workspace: `management-github-actions-oidc`
- `env-development/foundation-layer/gha-oidc/` → workspace: `development-foundation-gha-oidc`

**Note:** Both create `github-actions-dev-platform` role. The management account version may be redundant unless there's a cross-account use case. Consider clarifying the purpose or removing duplicate.

### 7. Missing CloudTrail Monitoring/Alerting

**ADR Requires:** "Enable CloudTrail logging for all AssumeRole events" and "Implement alerts for production role usage outside expected patterns"

**Current State:** No CloudTrail or alerting configuration found in terraform code.

---

## 📋 Summary Table

| ADR Requirement | Status | Notes |
|-----------------|--------|-------|
| Environment-based roles (dev/staging/prod) | ⚠️ Partial | Only dev implemented, staging/sandbox/prod missing |
| Execution context split (cicd/human) | ⚠️ Partial | Only CICD roles exist; IAM Identity Center covers console access |
| Layer-based subdivision | ✅ Good | Implemented for dev environment |
| Trust policy conditions | ✅ Good | Correct OIDC conditions |
| Session duration guidelines | ⚠️ | 2hr for all; dev could be longer |
| Permission boundaries | ❌ Missing | Variable exists but not used |
| Tagging compliance | ✅ Good | Most tags present |
| IAM Identity Center separation | ✅ Excellent | Full persona-based setup with 5 groups and permission sets |
| EKS Cluster Admin | ✅ New | 1Password integration for cluster connection details |
| GitHub Actions OIDC | ✅ Good | Both management and development accounts configured |
| CloudTrail monitoring | ❌ Missing | No audit infrastructure |
| Documentation/helper scripts | ⚠️ Partial | Some docs exist, more needed |

---

## 🔧 Recommended Actions

### Priority 1: Create missing environment roles (HIGH)

- Copy `env-development/foundation-layer/iam-roles-for-terraform/` to staging, sandbox, and production
- Adjust permissions (production should be more restrictive)

### Priority 2: Add human roles (MEDIUM)

- Create `terraform-{env}-{layer}-human-role` for each layer
- Use IdP group claims for trust policy conditions
- Note: IAM Identity Center permission sets already provide console access

### Priority 3: Use the reusable module (MEDIUM)

- Refactor `env-development/foundation-layer/iam-roles-for-terraform/` to use `terraform-modules/terraform-oidc-role/`
- This ensures consistency across environments

### Priority 4: Implement permission boundaries (LOW)

- Create a permission boundary policy that caps maximum permissions
- Attach to all terraform roles

### Priority 5: Tighten bootstrap role (LOW)

- Scope `terraform-cloud-oidc-role` to specific projects instead of wildcards
- Or create separate management-account roles per use case
- Note: IAM policy is already scoped to appropriate resources

### Priority 6: Add audit infrastructure (LOW)

- CloudTrail configuration for `AssumeRole` events
- CloudWatch alarms for unexpected role assumptions

### Priority 7: Clarify GitHub Actions OIDC setup (LOW)

- Review if both management and development accounts need `github-actions-dev-platform` role
- Rename management account role if it serves a different purpose
- Document the purpose of each GitHub Actions role

---

## 📈 ADR Implementation Phase Assessment

Based on current code, implementation is between **Phase 2 and Phase 3**:

- ✅ Phase 1 (basic environment separation): Complete for development
- ⚠️ Phase 1 incomplete: Missing staging/sandbox/production
- ✅ Phase 2 (human/cicd context): IAM Identity Center provides human access via permission sets
- ✅ Phase 3 (layer-based): Implemented for development with foundation/platform/applications roles

**Significant Progress:**

- IAM Identity Center now fully configured with 5 user personas
- EKS Cluster Admin provides 1Password integration for cluster access
- GitHub Actions OIDC configured in both management and development accounts

**Recommendation:** Complete Phase 1 for all environments (staging, sandbox, production) before adding more complexity.

---

## Next Steps

1. [ ] Create staging IAM roles (`env-staging/foundation-layer/iam-roles-for-terraform/`)
2. [ ] Create sandbox IAM roles (`env-sandbox/foundation-layer/iam-roles-for-terraform/`)
3. [ ] Create production IAM roles (`env-production/foundation-layer/iam-roles-for-terraform/`)
4. [x] ~~IAM Identity Center setup~~ - COMPLETE (groups, permission sets, account assignments)
5. [x] ~~EKS Cluster Admin for 1Password~~ - COMPLETE
6. [x] ~~GitHub Actions OIDC in development account~~ - COMPLETE
7. [ ] Refactor to use `terraform-modules/terraform-oidc-role/` module
8. [ ] Add human roles for Terraform CLI usage (optional - IAM Identity Center covers console)
9. [ ] Implement permission boundaries
10. [ ] Add CloudTrail monitoring terraform code
11. [ ] Review/clarify duplicate GitHub Actions OIDC setup in management account
