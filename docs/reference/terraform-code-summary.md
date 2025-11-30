# Terraform Code Summary

> **Last Updated:** 2025-11-29
>
> **Purpose:** This document provides a comprehensive summary of all Terraform code in the `/terraform` directory, including the purpose of each sub-folder and how the Terraform is managed (CLI, VCS-driven, or GitHub Actions).
>
> **Maintenance:** Ask an AI assistant to update this document when new Terraform code is added by providing the prompt: *"Please review the `/terraform` directory and update `/docs/reference/terraform-code-summary.md` with any new or changed Terraform configurations."*

## Table of Contents

- [Environment Structure Overview](#environment-structure-overview)
- [Management Environment](#management-environment)
- [Development Environment](#development-environment)
- [Sandbox Environment](#sandbox-environment)
- [Local Environment](#local-environment)
- [Terraform Management Methods](#terraform-management-methods)
- [Authentication Flow Diagram](#authentication-flow-diagram)
- [Key Observations](#key-observations)

## Environment Structure Overview

The workspace follows a **layered architecture** with environments separated into distinct AWS accounts:

| Environment | Purpose | Layers |
|-------------|---------|--------|
| `env-management` | Central management account for IAM, OIDC providers, and Terraform Cloud configuration | Foundation |
| `env-development` | Development AWS account for dev workloads | Foundation, Platform |
| `env-sandbox` | Testing, experimentation, and learning | Foundation, Platform, Applications |
| `env-local` | LocalStack-based local development | Foundation, Platform, Applications |

## Management Environment

**Path:** `terraform/env-management/`

### Foundation Layer

| Folder | Purpose | TFC Workspace | Management Method |
|--------|---------|---------------|-------------------|
| `terraform-cloud/` | Manages Terraform Cloud projects, workspaces, and configuration. Creates/configures all TFC workspaces for other layers. | `management-foundation-terraform-cloud` | **CLI-driven** with `TFE_TOKEN` env var |
| `terraform-cloud-oidc-role/` | Creates AWS OIDC provider and IAM role (`terraform-cloud-oidc-role`) that Terraform Cloud uses to authenticate to AWS in the management account | `management-foundation-tfc-oidc-role` | **VCS-driven** via TFC with OIDC auth |
| `iam-roles-for-people/` | Manages IAM Identity Center groups, permission sets (Admin, PlatformEngineer, ReadOnly), and account assignments across all accounts | `management-foundation-iam-roles-for-people` | **VCS-driven** via TFC with OIDC auth |
| `github-actions-oidc-role/` | Creates GitHub Actions OIDC provider and IAM role in management account for GHA to authenticate to AWS | `management-github-actions-oidc` | **VCS-driven** via TFC with OIDC auth |

> **Note:** `iam-roles-for-terraform` has been moved to each target account (e.g., `env-development`). IAM roles for Terraform Cloud must exist in the account where resources are provisioned.

## Development Environment

**Path:** `terraform/env-development/`

### Development Foundation Layer

| Folder | Purpose | TFC Workspace | Management Method |
|--------|---------|---------------|-------------------|
| `iam-roles-for-terraform/` | Creates TFC OIDC provider and layer-specific IAM roles (`terraform-dev-foundation-cicd-role`, `terraform-dev-platform-cicd-role`, `terraform-dev-applications-cicd-role`) in the development account | `development-foundation-iam-roles` | **VCS-driven** via TFC (bootstrap required) |
| `github-actions-oidc-role/` | Creates GitHub Actions OIDC provider and IAM role in the **development account** for GHA to provision EKS | `development-foundation-gha-oidc` | **VCS-driven** via TFC (needs bootstrap with dev account creds) |

### Platform Layer

| Folder | Purpose | TFC Workspace | Management Method |
|--------|---------|---------------|-------------------|
| `eks-auto-mode/` | EKS Auto Mode cluster with VPC, subnets, KMS encryption, and control plane logging | `development-platform-eks` | **GitHub Actions-driven** via TFC API (no VCS trigger) |

## Sandbox Environment

**Path:** `terraform/env-sandbox/`

### Sandbox Foundation Layer

| Folder | Purpose | TFC Workspace | Management Method |
|--------|---------|---------------|-------------------|
| `iam-roles-terraform/` | Creates OIDC IAM roles for all layers (foundation, platform, application, experiments) with both CI/CD and human access roles | `sandbox-foundation-iam-roles` | **VCS-driven** via TFC |

### Sandbox Experiments Layer

| Folder | Purpose | TFC Workspace | Management Method |
|--------|---------|---------------|-------------------|
| `experiments/` | Ad-hoc experiments and learning projects (placeholder for future use) | TBD | TBD |

### Sandbox Other Layers

- `platform-layer/` - Placeholder for test EKS clusters, RDS instances
- `applications-layer/` - Placeholder for test application deployments

## Local Environment

**Path:** `terraform/env-local/`

> **Note:** This environment uses LocalStack for local development without cloud backends.

### Sandbox Layer

| Folder | Purpose | Management Method |
|--------|---------|-------------------|
| `localhost-learning/` | LocalStack provider configuration for local development (S3, DynamoDB examples) | **CLI-driven** locally (no cloud backend) |

### Applications Layer

| Folder | Purpose | Management Method |
|--------|---------|-------------------|
| `eks-learning-cluster/` | EKS learning cluster using LocalStack | **CLI-driven** locally |

### Local Other Layers

- `foundation-layer/` - Placeholder
- `platform-layer/` - Placeholder

## Terraform Management Methods

| Method | Description | Authentication | Used By |
|--------|-------------|----------------|---------|
| **CLI with AWS SSO** | Run `terraform plan/apply` locally after `aws sso login` | AWS SSO credentials | `env-local/*`, bootstrap operations |
| **CLI with TFE_TOKEN** | Run `terraform plan/apply` locally with TFC remote execution | Terraform Cloud API token | `terraform-cloud/` workspace |
| **VCS-driven with TFC OIDC** | Push to GitHub → TFC detects change → TFC assumes `terraform-cloud-oidc-role` via OIDC → Runs plan/apply | TFC OIDC → AWS IAM Role | Most management & foundation workspaces |
| **GitHub Actions with AWS OIDC + TFC API** | GHA workflow assumes `github-actions-dev-platform` IAM role via OIDC, then triggers TFC run via API | GHA OIDC → AWS IAM Role + TFC API Token | `development-platform-eks` (EKS provisioning) |

## Authentication Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TERRAFORM CLOUD                                    │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐     │
│  │ management-        │  │ management-        │  │ management-        │     │
│  │ foundation-        │  │ foundation-iam-    │  │ github-actions-    │     │
│  │ terraform-cloud    │  │ roles-for-people   │  │ oidc               │     │
│  └─────────┬──────────┘  └─────────┬──────────┘  └─────────┬──────────┘     │
│            │                       │                       │                 │
│            │ TFE_TOKEN             │ OIDC                  │ OIDC            │
│            ▼                       ▼                       ▼                 │
│       ┌─────────┐          ┌─────────────────────────────────────┐          │
│       │   CLI   │          │   terraform-cloud-oidc-role         │          │
│       │ (local) │          │   (AWS IAM Role in Management)      │          │
│       └─────────┘          └─────────────────────────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           GITHUB ACTIONS                                     │
│                                                                              │
│  ┌────────────────────┐                                                      │
│  │ EKS Provisioning   │                                                      │
│  │ Workflow           │                                                      │
│  └─────────┬──────────┘                                                      │
│            │ OIDC                                                            │
│            ▼                                                                 │
│  ┌─────────────────────────────────────────────┐                            │
│  │ github-actions-dev-platform                 │                            │
│  │ (AWS IAM Role in Development Account)       │                            │
│  └─────────────────────────────────────────────┘                            │
│            │                                                                 │
│            │ TFC API Token                                                   │
│            ▼                                                                 │
│  ┌─────────────────────────────────────────────┐                            │
│  │ development-platform-eks (TFC Workspace)    │                            │
│  └─────────────────────────────────────────────┘                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Observations

### When to Use Each IAM Role Pattern

Each target AWS account needs OIDC roles for CI/CD authentication. The choice depends on **who controls the Terraform execution**:

| Pattern | Folder Name | Purpose | Who Assumes the Role |
|---------|-------------|---------|----------------------|
| **VCS-driven** | `iam-roles-for-terraform/` | TFC workspaces triggered by git push | Terraform Cloud |
| **GHA-driven** | `github-actions-oidc-role/` | Workflows where GitHub Actions controls execution | GitHub Actions |

#### Decision Guide

**Choose VCS-driven (`iam-roles-for-terraform`)** when:

- Simple Terraform workflows are sufficient
- You want automatic runs on git push to trigger TFC
- No complex orchestration or pre/post steps are needed
- Standard infrastructure provisioning (IAM, networking, databases, etc.)

**Choose GHA-driven (`github-actions-oidc-role`)** when:

- GitHub Actions needs to control workflow execution timing
- Complex CI/CD orchestration is required (e.g., run tests before apply)
- You need pre/post Terraform steps (e.g., EKS with kubectl commands)
- Tighter integration with GitHub's CI/CD features (matrix builds, approvals, etc.)

#### Authentication Flow Comparison

```text
VCS-Driven:
  Git Push → Terraform Cloud → assumes iam-roles-for-terraform → AWS

GHA-Driven:
  Git Push → GitHub Actions → assumes github-actions-oidc-role → AWS
                           → (optionally) triggers TFC via API
```

### Bootstrap Order

1. `terraform-cloud-oidc-role` must be created first (possibly via CLI with SSO) before VCS-driven workspaces can authenticate
2. The `terraform-cloud/` workspace manages all other TFC workspaces and must be run via CLI

### Multi-Account Setup

- **Management account** holds the central OIDC providers for Terraform Cloud
- **Development account** has its own GitHub Actions OIDC provider for GHA-driven EKS provisioning
- **Sandbox account** is isolated for experimentation with broader permissions

### ADR-013 Pattern

EKS provisioning uses the GitHub Actions OIDC → TFC API pattern instead of pure VCS-driven workflows. This allows:

- GitHub Actions to control when Terraform runs
- AWS credentials to be obtained via GitHub's OIDC provider
- Better integration with GitHub-based CI/CD pipelines

### LocalStack for Local Development

`env-local` uses LocalStack for local testing without cloud backends, enabling:

- Fast iteration during development
- No cloud costs for experimentation
- Offline development capability

## Related Documentation

- [ADR-009: Folder Structure](./architecture-decision-register/ADR-009-folder-structure.md)
- [ADR-013: GitHub Actions OIDC for EKS](./architecture-decision-register/ADR-013-github-actions-oidc.md) *(if exists)*
- [Terraform Cloud OIDC Setup Guide](../how-to-guides/terraform-cloud-oidc-setup-checklist.md)
- [Sandbox Environment README](../../terraform/env-sandbox/README.md)

---

## Appendix: Quick Reference

### Terraform Cloud Organization

- **Organization:** `Datafaced`
- **URL:** <https://app.terraform.io/app/Datafaced>

### TFC Projects

| Project | ID | Purpose |
|---------|-----|---------|
| `aws-management` | `prj-TUuCF429ZkiWqkS4` | Management account workspaces |
| `aws-development` | `prj-Cj6n3zmJXuMKCD2z` | Development account workspaces |
| `aws-staging` | `prj-i6DD3NyNdyv87kQ6` | Staging account workspaces |
| `aws-production` | `prj-iH2gV7RgSDXLFgKX` | Production account workspaces |
| `aws-sandbox` | `prj-P5C49cDctjUiVAzy` | Sandbox account workspaces |

### Key IAM Roles

| Role Name | Account | Purpose |
|-----------|---------|---------|
| `terraform-cloud-oidc-role` | Management (169506999567) | TFC OIDC authentication for management account workspaces |
| `terraform-dev-foundation-cicd-role` | Development (126350206316) | TFC role for dev foundation layer workspaces |
| `terraform-dev-platform-cicd-role` | Development (126350206316) | TFC role for dev platform layer workspaces |
| `terraform-dev-applications-cicd-role` | Development (126350206316) | TFC role for dev applications layer workspaces |
| `github-actions-dev-platform` | Development (126350206316) | GHA OIDC for EKS provisioning |

---

*This document is maintained as part of the infrastructure documentation. For questions or updates, please open an issue or PR.*
