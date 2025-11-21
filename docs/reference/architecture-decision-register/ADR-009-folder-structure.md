# ADR-009: Terraform Folder Structure Organization

## Status

Approved

## Date

2025-11-02

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
│   │   └── README.md
│   ├── platform-layer/
│   │   └── README.md
│   ├── applications-layer/
│   │   ├── README.md
│   │   └── eks-learning-cluster/
│   └── sandbox-layer/            # Experimental and learning resources
│       └── localhost-learning/
├── env-development/              # AWS development environment
│   ├── foundation-layer/
│   │   └── iam-roles-terraform/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars
│   └── applications-layer/
│       └── eks-learning-cluster/
│           ├── main7.tf
│           ├── outputs.tf
│           ├── README.md
│           ├── START-HERE.md
│           ├── SUMMARY.md
│           └── QUICK-REFERENCE.md
├── env-management/               # AWS management/control plane
│   └── foundation-layer/
│       ├── iam-roles-for-people/
│       └── iam-roles-for-terraform/
└── terraform-modules/            # Reusable infrastructure modules
    ├── permission-set/
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── variables.tf
    │   └── examples/
    └── terraform-oidc-role/
        ├── main.tf
        ├── outputs.tf
        ├── policies.tf
        └── variables.tf
```

## Rationale

### Key Implementation Details

Our implementation includes these specialized environment types:

- **`env-local/`**: LocalStack-based local development environment for rapid iteration without AWS costs
- **`env-management/`**: AWS control plane for IAM Identity Center, organizational IAM roles, and cross-account resources
- **`env-development/`**: AWS development workload environment for testing real cloud resources
- **`env-staging/`** (future): AWS staging environment for pre-production validation
- **`env-production/`** (future): AWS production environment for live workloads

The `env-local` environment includes a unique `sandbox-layer/` for experimental and learning resources that don't fit traditional infrastructure layers.

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
- `development-applications-eks-learning-cluster`
- `management-foundation-iam-roles-for-people`
- `production-platform-eks-cluster`

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

```bash
# env-development/applications-layer/eks-learning-cluster/main.tf
module "eks" {
  source = "../../../terraform-modules/eks"
  
  environment     = "development"
  cluster_name    = "development-learning-cluster"
  cluster_version = "1.28"
  
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
