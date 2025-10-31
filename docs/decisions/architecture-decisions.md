# ADR Index

> Quick reference for all Architecture Decision Records. Read the full ADR for complete context.

**Last Updated**: October 28, 2025

---

## Active Decisions

| ID | Title | Decision | Status | Date |
|----|-------|----------|--------|------|
| [ADR-001](./architecture/ADR-001-terraform-state-management.md) | Terraform State Management | Use Terraform Cloud (not AWS S3) | Approved | 2025-10-25 |
| [ADR-002](./architecture/ADR-002-terraform-workflow-git-cicd.md) | Terraform Workflow Setup | VCS-driven with mono-branch + directories | Proposed | 2025-10-28 |
| [ADR-003](./architecture/ADR-003-infrastructure-layering-repository-structure.md) | Infrastructure Layering & Repository Structure | Infra monorepo (layered) + separate app repos | Proposed | 2025-10-28 |
| [ADR-004](./architecture/ADR-004-infrastructure-tooling-separation.md) | Infrastructure Tooling Separation - Terraform, Helm, and Kubernetes CRDs | Layered approach: Terraform for cloud + Helm for platform services + K8s CRDs for app infra | Proposed | 2025-10-28 |

## Superseded Decisions

| ID | Title | Superseded By | Date |
|----|-------|---------------|------|
| - | - | - | - |

---

## For AI Assistants

When working with this codebase, follow decisions in Active ADRs:

- **Repository structure**: Infrastructure monorepo (layered) + separate application code repos
- **Infrastructure layers**: Foundation → Platform → Shared Services → Applications
- **Application deployments**: Code deploys via app CI/CD (no Terraform), infrastructure changes via Terraform
- **Terraform state**: Use Terraform Cloud with separate workspaces per layer per environment
- **Git workflow**: Single main branch with environment directories (environments/dev, environments/staging, environments/production)
- **Terraform Cloud**: VCS-driven workflow, workspaces linked to main branch with working directory filters
- **Deployments**: Dev and Staging auto-apply, Production requires manual approval
- **Scaling**: Prefer auto-scaling policies in Terraform; manual scaling via Terraform or AWS CLI
- **Dependencies**: Use terraform_remote_state to reference outputs from other layers
- **Cloud strategy**: Currently AWS-only, but design for multi-cloud
- **Security**: Implement least privilege, use Terraform Cloud RBAC and Sentinel policies
- **Environments**: Separate AWS accounts for Dev, Staging, Production
 - **Tooling boundaries**: Use Terraform for AWS infra and EKS clusters, Helm for platform K8s services, and K8s CRDs/manifest workflows for application-level resources (see ADR-004)

Check the full ADR when you need implementation details or constraints.