# ADR Index

> Quick reference for all Architecture Decision Records. Read the full ADR for complete context.

**Last Updated**: November 17, 2025

---

## Active Decisions

| ID | Title | Decision | Status | Date |
|----|-------|----------|--------|------|
| [ADR-001](./architecture-decision-register/ADR-001-terraform-state-management.md) | Terraform State Management | Use Terraform Cloud (not AWS S3) | Approved | 2025-10-25 |
| [ADR-002](./architecture-decision-register/ADR-002-terraform-workflow-git-cicd.md) | Terraform Workflow Setup | VCS-driven with mono-branch + directories | Approved | 2025-10-28 |
| [ADR-003](./architecture-decision-register/ADR-003-infra-layering-repository-structure.md) | Infrastructure Layering & Repository Structure | Infra monorepo (layered) + separate app repos with GitOps | Approved | 2025-10-28 |
| [ADR-004](./architecture-decision-register/ADR-004-infra-tooling-separation.md) | Infrastructure Tooling Separation - Terraform, Helm, and Kubernetes CRDs | Layered approach: Terraform for cloud + Helm for platform services + K8s CRDs for app infra + ArgoCD for GitOps | Approved | 2025-10-28 |
| [ADR-005](./architecture-decision-register/ADR-005-secrets-manager.md) | Selection of Cloud-Based Secrets Manager Service | Use AWS Secrets Manager (automation-first approach) | Approved | 2025-10-31 |
| [ADR-006](./architecture-decision-register/ADR-006-kms-key-management.md) | KMS Key Management Strategy | Per-environment customer-managed KMS keys (dev, staging, prod) | Approved | 2025-10-31 |
| [ADR-007](./architecture-decision-register/ADR-007-iam-for-parameter-store.md) | IAM Policy Design for Secrets Manager Access | Environment-scoped policies with read-only GitHub Actions | Approved | 2025-10-31 |
| [ADR-008](./architecture-decision-register/ADR-008-secret-rotation.md) | Secret Rotation Implementation Patterns | Hybrid GitHub Actions with service-specific rotation strategies | Approved | 2025-10-31 |
| [ADR-009](./architecture-decision-register/ADR-009-folder-structure.md) | Terraform Folder Structure Organization | Environments → Layers → Stacks pattern | Approved | 2025-11-02 |
| [ADR-010](./architecture-decision-register/ADR-010-aws-aim-role-structure.md) | AWS IAM Role Structure for Terraform OIDC Authentication | Tiered IAM role structure based on environment separation | Approved | 2025-11-02 |
| [ADR-011](./architecture-decision-register/ADR-011-sandbox-environment.md) | Sandbox Environment for Testing and Experimentation | Dedicated AWS account with standard layers + experiments layer | Approved | 2025-11-17 |

## Superseded Decisions

| ID | Title | Superseded By | Date |
|----|-------|---------------|------|
| - | - | - | - |

---

## For AI Assistants

When working with this codebase, follow decisions in Active ADRs:

**Infrastructure & Repository:**

- **Repository structure**: Infrastructure monorepo (layered) + separate application code repos + k8s-manifests repo for GitOps
- **Infrastructure layers**: Foundation → Platform → Shared Services → Applications
- **Folder structure**: Environments → Layers → Stacks (e.g., `env-development/foundation-layer/iam-roles-terraform/`)
- **Environment types**: `env-local` (LocalStack), `env-management` (control plane), `env-sandbox` (testing), `env-development`, `env-staging`, `env-production`
- **Reusable modules**: Stored in `terraform-modules/` at repository root
- **Application deployments**: Code deploys via app CI/CD with GitOps (ArgoCD), infrastructure changes via Terraform
- **Tooling boundaries**: Terraform for AWS infra and EKS clusters, Helm for platform K8s services, K8s CRDs/manifests for app resources
- **GitOps workflow**: App CI/CD updates k8s-manifests repo → ArgoCD auto-syncs to cluster (no manual kubectl needed)

**Terraform & Git Workflow:**

- **Terraform state**: Terraform Cloud with separate workspaces per layer per environment (not AWS S3)
- **Workspace naming**: `{environment}-{layer}-{stack}` (e.g., `development-foundation-iam-roles-terraform`)
- **Git workflow**: Single main branch with environment directories
- **Terraform Cloud**: VCS-driven workflow, workspaces linked to main branch with working directory filters
- **Deployments**: Dev/Staging auto-apply, Production requires manual approval
- **Dependencies**: Use `terraform_remote_state` to reference outputs from other layers
- **Scaling**: Auto-scaling policies in Terraform (HPA for K8s), manual scaling via Terraform or AWS CLI if needed

**Secrets Management:**

- **Secrets storage**: AWS Secrets Manager for automation-first approach (infrastructure secrets)
- **KMS encryption**: Per-environment customer-managed KMS keys (dev, staging, prod keys are separate)
- **Key rotation**: Automatic KMS key rotation enabled (annually)
- **Naming convention**: Secrets as `{environment}/{service}/{secret-name}`
- **IAM access**: Environment-scoped policies; GitHub Actions has read-only access via OIDC
- **Secret rotation**: Automated rotation via GitHub Actions with service-specific strategies:
  - Simple replacement for app secrets
  - Coordinated updates for database credentials
  - Dual-key pattern for external API keys (7-day grace period)
- **Rotation schedule**: 90 days for database/app secrets, manual for external API keys
- **K8s integration**: Use External Secrets Operator to sync AWS Secrets Manager to K8s secrets

**Security & Access Control:**

- **Authentication**: GitHub Actions uses OIDC (no long-lived credentials)
- **OIDC IAM Roles**: Environment-based tiered structure (`terraform-{env}-role` pattern, optionally split by execution context: `terraform-{env}-cicd-role` vs `terraform-{env}-human-role`)
- **IAM Identity Center**: Used for human AWS Console/CLI access, separate from OIDC roles for Terraform
- **Permission separation**: OIDC roles for Terraform automation, Permission Sets for human access
- **Authorization**: Environment-scoped IAM policies prevent cross-environment access
- **GitHub Actions**: Read-only Secrets Manager access, cannot write/create secrets
- **KMS permissions**: Requires both IAM and KMS permissions to decrypt secrets
- **Audit**: CloudTrail logging for all Secrets Manager and KMS key access
- **Least privilege**: Read-only for CI/CD, read-write only for operators

**Kubernetes & GitOps:**

- **GitOps tool**: ArgoCD for continuous deployment
- **Manifest repository**: Separate k8s-manifests repo with Kustomize overlays per environment
- **Application workflow**: App CI builds image → updates k8s-manifests → ArgoCD syncs to cluster
- **Foundation services**: Platform team manages via Helm values in k8s-manifests, deployed by ArgoCD
- **Application resources**: Engineers define in k8s-manifests using K8s native resources and CRDs (Istio, etc.)
- **Service mesh**: Istio deployed via Helm, VirtualServices defined as CRDs in app manifests
- **Policy enforcement**: Kyverno deployed via Helm, policies defined as CRDs

**Multi-Cloud & Environments:**

- **Cloud strategy**: Currently AWS-only, designed for future multi-cloud
- **Environment purposes**:
  - `env-local`: LocalStack for local development (no AWS costs)
  - `env-management`: AWS control plane (IAM Identity Center, organizational roles)
  - `env-sandbox`: AWS testing, learning, and experimentation (dedicated account with automated cleanup)
  - `env-development`: AWS development workloads
  - `env-staging`: AWS pre-production validation (future)
  - `env-production`: AWS live workloads (future)
- **Compliance**: Terraform Cloud RBAC, Sentinel policies, CloudTrail audit logs

**Cost Optimization:**

- **Secrets Manager**: ~$0.40 per secret/month (justified for automation benefits)
- **KMS keys**: $1 per key/month ($3 total for dev/staging/prod)
- **LocalStack**: Free tier for local development to reduce AWS costs
- **Auto-scaling**: HPA in K8s reduces over-provisioning

Check the full ADR when you need implementation details or constraints.
