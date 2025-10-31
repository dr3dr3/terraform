# ADR Index

> Quick reference for all Architecture Decision Records. Read the full ADR for complete context.

**Last Updated**: October 31, 2025

---

## Active Decisions

| ID | Title | Decision | Status | Date |
|----|-------|----------|--------|------|
| [ADR-001](./architecture/ADR-001-terraform-state-management.md) | Terraform State Management | Use Terraform Cloud (not AWS S3) | Approved | 2025-10-25 |
| [ADR-002](./architecture/ADR-002-terraform-workflow-git-cicd.md) | Terraform Workflow Setup | VCS-driven with mono-branch + directories | Proposed | 2025-10-28 |
| [ADR-003](./architecture/ADR-003-infra-layering-repository-structure.md) | Infrastructure Layering & Repository Structure | Infra monorepo (layered) + separate app repos | Proposed | 2025-10-28 |
| [ADR-004](./architecture/ADR-004-infra-tooling-separation.md) | Infrastructure Tooling Separation - Terraform, Helm, and Kubernetes CRDs | Layered approach: Terraform for cloud + Helm for platform services + K8s CRDs for app infra | Proposed | 2025-10-28 |
| [ADR-005](./architecture/ADR-005-secrets-manager.md) | Selection of Cloud-Based Secrets Manager Service | Use AWS Systems Manager Parameter Store (Standard Parameters with SecureString) | Proposed | 2025-10-31 |
| [ADR-006](./architecture/ADR-006-kms-key-management.md) | KMS Key Management Strategy | Per-environment customer-managed KMS keys (dev, staging, prod) | Accepted | 2025-10-31 |
| [ADR-007](./architecture/ADR-007-iam-for-parameter-store.md) | IAM Policy Design for Parameter Store Access | Environment-scoped policies with read-only GitHub Actions | Accepted | 2025-10-31 |
| [ADR-008](./architecture/ADR-008-secret-rotation.md) | Secret Rotation Implementation Patterns | Hybrid GitHub Actions with service-specific rotation strategies | Accepted | 2025-10-31 |

## Superseded Decisions

| ID | Title | Superseded By | Date |
|----|-------|---------------|------|
| - | - | - | - |

---

## For AI Assistants

When working with this codebase, follow decisions in Active ADRs:

**Infrastructure & Repository:**
- **Repository structure**: Infrastructure monorepo (layered) + separate application code repos
- **Infrastructure layers**: Foundation → Platform → Shared Services → Applications
- **Application deployments**: Code deploys via app CI/CD (no Terraform), infrastructure changes via Terraform
- **Tooling boundaries**: Use Terraform for AWS infra and EKS clusters, Helm for platform K8s services, and K8s CRDs/manifest workflows for application-level resources

**Terraform & Git Workflow:**
- **Terraform state**: Use Terraform Cloud with separate workspaces per layer per environment
- **Git workflow**: Single main branch with environment directories (environments/dev, environments/staging, environments/production)
- **Terraform Cloud**: VCS-driven workflow, workspaces linked to main branch with working directory filters
- **Deployments**: Dev and Staging auto-apply, Production requires manual approval
- **Scaling**: Prefer auto-scaling policies in Terraform; manual scaling via Terraform or AWS CLI
- **Dependencies**: Use terraform_remote_state to reference outputs from other layers

**Secrets Management:**
- **Secrets storage**: Use AWS Systems Manager Parameter Store (Standard Parameters with SecureString) for cost optimization
- **KMS encryption**: Per-environment customer-managed KMS keys (separate keys for dev, staging, prod for environment isolation)
- **Naming convention**: Parameters organized as `/{environment}/{service}/{secret-name}`
- **IAM access**: Environment-scoped policies; GitHub Actions has read-only access via OIDC
- **Secret rotation**: Automated rotation via GitHub Actions with service-specific strategies (simple replacement, coordinated database updates, dual-key pattern for API keys)
- **Rotation schedule**: 90 days for database/app secrets, manual for external API keys with 7-day grace period

**Security & Access Control:**
- **Authentication**: GitHub Actions uses OIDC (no long-lived credentials)
- **Authorization**: Environment-scoped IAM policies prevent cross-environment access
- **Encryption**: KMS automatic key rotation enabled (annually)
- **Audit**: CloudTrail logging for all parameter and KMS key access
- **Least privilege**: Read-only access for CI/CD, read-write only for operators

**Multi-Cloud & Environments:**
- **Cloud strategy**: Currently AWS-only, but design for multi-cloud
- **Environments**: Separate AWS accounts for Dev, Staging, Production
- **Security**: Implement least privilege, use Terraform Cloud RBAC and Sentinel policies

Check the full ADR when you need implementation details or constraints.