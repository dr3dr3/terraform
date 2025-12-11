# ADR-009: Terraform Folder Structure Organization

## Status

Approved

## Date

2025-11-02 (Updated: 2025-12-08)

## Context

We need to establish a standardized folder structure for our Terraform infrastructure-as-code (IaC) repository. The structure must support multiple environments (dev, staging, production), different architectural layers (foundation, platform, applications), and various services/stacks (web-app, EKS clusters, etc.).

The folder structure decision impacts:

- Developer productivity and ease of navigation
- Risk management and blast radius containment
- State file management and isolation
- CI/CD pipeline design
- Access control and security boundaries
- Code reusability and maintainability
- Team onboarding and mental models

Four primary organizational patterns were considered:

1. **Layers → Environments → Stacks**: Organize by architectural layer first
2. **Environments → Layers → Stacks**: Organize by environment first (traditional)
3. **Layers → Stacks → Environments**: Organize by layer, then service, then environment
4. **Environments → Layers → Stacks** (with specialized environments): Our implemented approach with `env-local`, `env-management`, and workload environments

## Decision

We will adopt **Environments → Layers → Stacks** as our Terraform folder structure pattern, with specialized environment types for different purposes (local development, management plane, and workload environments).

```bash
terraform/
├── env-local/                    # Local development with LocalStack
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── applications-layer/
│   │   └── eks-learning-cluster/ # Learning/tutorial resources
│   └── sandbox-layer/
│       └── localhost-learning/
├── env-development/              # AWS development environment
│   ├── foundation-layer/
│   │   ├── gha-oidc/
│   │   └── iam-roles-for-terraform/
│   └── platform-layer/
│       └── eks-auto-mode/        # EKS cluster in platform layer
├── env-staging/                  # AWS staging environment
│   ├── foundation-layer/
│   │   ├── gha-oidc/
│   │   └── iam-roles-for-terraform/
│   └── platform-layer/
│       └── eks-auto-mode/
├── env-production/               # AWS production environment
│   ├── foundation-layer/
│   │   ├── gha-oidc/
│   │   └── iam-roles-for-terraform/
│   └── platform-layer/
│       └── eks-auto-mode/
├── env-sandbox/                  # AWS sandbox environment
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── applications-layer/
│   └── sandbox-layer/
├── env-management/               # AWS management/control plane
│   └── foundation-layer/
│       ├── eks-1password/
│       ├── eks-cluster-admin/
│       ├── gha-oidc/
│       ├── github-dr3dr3/
│       ├── iam-roles-for-people/
│       ├── terraform-cloud/
│       └── tfc-oidc-role/
└── terraform-modules/            # Reusable infrastructure modules
    ├── permission-set/
    └── terraform-oidc-role/
```

## Rationale

### Key Implementation Details

Our implementation includes these specialized environment types:

- **`env-local/`**: LocalStack-based local development environment for rapid iteration without AWS costs
- **`env-management/`**: AWS control plane for IAM Identity Center, organizational IAM roles, Terraform Cloud configuration, and cross-account resources
- **`env-sandbox/`**: AWS sandbox environment for experimentation and proof-of-concepts
- **`env-development/`**: AWS development workload environment for testing real cloud resources
- **`env-staging/`**: AWS staging environment for pre-production validation
- **`env-production/`**: AWS production environment for live workloads

The `env-local` and `env-sandbox` environments include a `sandbox-layer/` for experimental and learning resources that don't fit traditional infrastructure layers.

### Layer Definitions and Contents

Each layer has a specific purpose and contains particular types of infrastructure:

#### Foundation Layer (`foundation-layer/`)

**Purpose**: Core AWS infrastructure that rarely changes and has no dependencies on other layers.

**Contains**:

- IAM roles and policies (for Terraform, GitHub Actions, people)
- VPCs, subnets, route tables, NAT gateways
- Security groups (shared/baseline)
- DNS zones (Route 53 hosted zones)
- ACM certificates
- KMS keys
- S3 buckets (for logs, artifacts)
- OIDC providers (GitHub Actions, Terraform Cloud)

**Change Frequency**: Rarely (weeks to months)

#### Platform Layer (`platform-layer/`)

**Purpose**: Compute platforms and managed services that application workloads run on. These are AWS-managed resources that provide the runtime environment.

**Contains**:

- **EKS clusters** (control plane, node groups, managed add-ons)
- ECS clusters
- RDS instances (shared databases)
- ElastiCache clusters
- MSK (Kafka) clusters
- Load balancers (ALB/NLB shared across applications)
- Service mesh control plane infrastructure (if AWS-managed)

**Change Frequency**: Infrequently (days to weeks)

**Key Principle**: The Platform Layer provides the compute substrate. It answers: "Where do workloads run?"

#### Applications Layer (`applications-layer/`)

**Purpose**: Application workloads deployed to the platforms, and any application-specific AWS resources.

**Contains**:

- **Kubernetes workloads deployed via Terraform** (when not using GitOps):
  - Cluster utilities: Istio, Kyverno, Prometheus, Grafana, Jaeger, Tailscale
  - ArgoCD bootstrap configuration
  - Namespace and RBAC setup
  - Initial Helm releases for platform services
- **Application-specific AWS resources**:
  - Application-specific S3 buckets
  - Application-specific RDS databases
  - SQS queues, SNS topics
  - Secrets Manager secrets
  - Application-specific IAM roles (IRSA)

**Change Frequency**: Moderate (days), but see GitOps note below

**GitOps Integration**: In practice, **most application-layer Kubernetes workloads are NOT managed by Terraform**. We use ArgoCD with a GitOps approach:

- Terraform in this layer primarily:
  1. Bootstraps ArgoCD itself
  2. Creates AWS resources needed by applications (S3, RDS, IAM roles for service accounts)
  3. Sets up initial namespaces/RBAC if not managed by ArgoCD
- Kubernetes manifests for workloads (both utilities like Istio and business apps like web services) live in a **separate GitOps repository** and are managed by ArgoCD
- This separation keeps Terraform focused on AWS infrastructure while Kubernetes-native tooling manages in-cluster resources

**Workload Categories** (managed via GitOps, not Terraform):

| Category | Examples | Purpose |
|----------|----------|---------|
| Cluster Utilities | Istio, Kyverno, Cert-Manager, External-DNS | Foundation for other workloads |
| Observability | Prometheus, Grafana, Jaeger, Loki | Monitoring and tracing |
| Security | Falco, Trivy, OPA/Gatekeeper | Runtime security |
| Connectivity | Tailscale, VPN operators | Secure access |
| Business Workloads | 3-tier web apps, APIs, workers | End-user facing applications |

#### Sandbox Layer (`sandbox-layer/`) - env-local only

**Purpose**: Experimental and learning resources that don't fit traditional infrastructure patterns.

**Contains**:

- Learning exercises
- Proof-of-concept configurations
- Experimental features
- Training materials

**Change Frequency**: Ad-hoc

### Why This Structure Was Chosen

1. **Environment Isolation and Safety**
   - Each environment is completely isolated at the top level
   - Reduces risk of accidentally applying changes to the wrong environment
   - Clear mental model: "I'm working in dev" vs "I'm working in production"
   - Easier to implement strict access controls per environment

2. **State Management**
   - Natural boundary for separate Terraform Cloud workspaces (one per layer per environment)
   - Reduces state file contention and locking issues
   - Enables independent lifecycle management for different layers
   - Example workspaces: `development-foundation-networking`, `production-platform-eks-cluster`

3. **Blast Radius Containment**
   - Changes in one environment cannot affect others
   - Layer separation within environment contains impact of failures
   - Testing in dev environment has zero risk to production

4. **Industry Standard Practice**
   - Most widely adopted pattern in the Terraform community
   - Better documentation and community support
   - Easier for new team members familiar with Terraform conventions
   - Aligns with most Terraform tooling (Terragrunt, Atlantis, etc.)

5. **CI/CD Pipeline Alignment**
   - Deployment pipelines naturally organize by environment
   - Environment promotion workflows are clearer (dev → staging → prod)
   - Easier to implement environment-specific approval gates
   - Path-based CI/CD triggers are more intuitive

6. **Access Control and Compliance**
   - Can enforce different IAM policies per environment directory
   - Easier to implement compliance requirements per environment
   - Production access can be strictly limited
   - Audit trails are clearer when organized by environment

### Alternatives Considered

#### Option 1: Layers → Environments → Stacks

**Rejected because:**

- Harder to visualize complete environment state
- More navigation required to see all resources in an environment
- Environment-wide changes require touching multiple layer directories
- Less intuitive for common operations ("deploy to staging")

**When it might be appropriate:**

- Organizations with very strong layer-based teams
- When layers have very different lifecycles
- When layer-based access control is primary concern

#### Option 3: Layers → Stacks → Environments

**Rejected because:**

- Highest risk of cross-environment contamination
- Difficult to reason about complete environment state
- Less common pattern (steeper learning curve)
- Harder to implement environment-level security controls

**When it might be appropriate:**

- Very small projects with few services
- When comparing service configuration across environments is primary workflow
- Single-person projects with minimal risk

#### Why Not Pure Option 2?

Our implementation extends the traditional Option 2 pattern by recognizing that not all "environments" are equal:

- **Management environment** (`env-management/`) serves a fundamentally different purpose than workload environments
- **Local environment** (`env-local/`) uses different tooling (LocalStack) and has different constraints
- **Sandbox layer** exists only in `env-local/` for learning resources that don't fit standard patterns

This pragmatic approach acknowledges that infrastructure has different operational contexts while maintaining the core benefits of environment-first organization.

## Consequences

### Positive

- **Reduced Risk**: Clear environment boundaries prevent accidental cross-environment changes
- **Better Security**: Easier to implement environment-specific access controls
- **Improved Developer Experience**: Intuitive navigation and mental model
- **Scalability**: Structure scales well as number of services grows
- **Tool Compatibility**: Works well with Terraform best practices and tooling ecosystem
- **Clear State Management**: Natural state file boundaries reduce conflicts
- **CI/CD Friendly**: Aligns with standard deployment pipeline patterns

### Negative

- **Code Duplication**: Same infrastructure code repeated across environments (mitigated by modules)
- **Cross-Environment Visibility**: Harder to see all instances of a service across environments at once
- **More Directories**: More folder navigation required in some scenarios

### Mitigation Strategies

1. **Code Reusability**: Create reusable modules in `terraform-modules/` directory to eliminate duplication
2. **Consistency**: Use Terraform Cloud workspace templates and variable sets to reduce boilerplate across environments
3. **Documentation**: Maintain a service inventory document showing cross-environment view
4. **Tooling**: Use Terraform Cloud UI and API to provide cross-environment visibility when needed
5. **Variable Sets**: Use Terraform Cloud variable sets to manage environment-specific configurations centrally

## Implementation Notes

### State Backend Configuration

Per [ADR-001: Terraform State Management Backend](./ADR-001-terraform-state-management.md), we use **Terraform Cloud** for state management in AWS environments.

Each layer in each environment should have its own Terraform Cloud workspace:

```bash
# env-development/foundation-layer/iam-roles-terraform/backend.tf
terraform {
  cloud {
    organization = "your-organization"
    
    workspaces {
      name = "development-foundation-iam-roles-terraform"
      # Or use tags for dynamic workspace selection:
      # tags = ["development", "foundation", "iam"]
    }
  }
}
```

**Workspace Naming Convention:**
`{environment}-{layer}-{stack-name}`

Examples:

- `development-foundation-iam-roles-terraform`
- `development-foundation-networking`
- `development-platform-eks`
- `development-applications-argocd-bootstrap`
- `management-foundation-iam-roles-for-people`
- `production-platform-eks`

For `env-local` using LocalStack, state is stored locally since Terraform Cloud is not needed for local development:

```bash
# env-local/foundation-layer/networking/backend.tf
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### Module Usage Pattern

```hcl
# env-development/platform-layer/eks/main.tf
module "eks" {
  source = "../../../terraform-modules/eks"
  
  environment     = "development"
  cluster_name    = "development-eks"
  cluster_version = "1.31"
  
  # Reference foundation layer outputs via Terraform Cloud remote state
  vpc_id     = data.tfe_outputs.networking.values.vpc_id
  subnet_ids = data.tfe_outputs.networking.values.private_subnet_ids
}

# Remote state data source for Terraform Cloud
data "tfe_outputs" "networking" {
  organization = "your-organization"
  workspace    = "development-foundation-networking"
}
```

```hcl
# env-development/applications-layer/argocd-bootstrap/main.tf
# Minimal Terraform to bootstrap ArgoCD - workloads managed via GitOps after this
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  
  # ArgoCD then manages all other Kubernetes workloads via GitOps
}
```

Note: Reusable modules are stored in `terraform-modules/` at the repository root level, not within the `terraform/` directory.

### Naming Conventions

- Environments: `env-{name}` (e.g., `env-local`, `env-development`, `env-management`, `env-staging`, `env-production`)
- Layers: `{name}-layer` (e.g., `foundation-layer`, `platform-layer`, `applications-layer`, `sandbox-layer`)
- Stacks: Descriptive names (e.g., `iam-roles-terraform`, `eks-learning-cluster`, `iam-roles-for-people`)
- Modules directory: `terraform-modules/` (not `modules/`) to distinguish from potential application modules

### Layer Dependencies

See [ADR-003: Infrastructure Layering and Repository Struture](./ADR-003-infra-layering-repository-structure.md)

## References

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Gruntwork Terraform Module Structure](https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d)
- [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- [HashiCorp Terraform Recommended Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)

## Review and Updates

- **Next Review Date**: 2026-05-02 (6 months)
- **Review Triggers**:
  - Addition of 5+ new environments
  - Significant team size changes
  - Major Terraform version upgrades
  - Persistent pain points with current structure
