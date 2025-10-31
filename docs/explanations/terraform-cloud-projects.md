# Terraform Cloud - Projects versus Workspaces

Projects in Terraform Cloud serve as an **organizational and access control layer** above Workspaces. While Workspaces handle the actual operational concerns (state, variables, runs), Projects provide several valuable functions:

## Key Benefits of Projects

**Access Control & Permissions**
Projects allow you to group workspaces and apply team-based access controls at the project level. Instead of managing permissions workspace-by-workspace, you can grant teams access to all workspaces within a project. This scales much better as your infrastructure grows.

**Logical Organization**
Projects help you organize workspaces by application, environment, team, or business unit. For example, you might have a "Platform Engineering" project containing workspaces for shared infrastructure, and an "E-commerce" project with workspaces for your storefront services.

**Variable Sets**
You can define variable sets at the project level that automatically apply to all workspaces within that project. This is excellent for shared credentials, common tags, or organizational standards that should be consistent across related infrastructure.

**Visibility & Discovery**
Projects make it easier to find related workspaces and understand how your infrastructure is organized. Without projects, a large organization might have hundreds of workspaces in a flat list.

**Future Capabilities**
Projects provide a foundation for future features like project-level policies, project-scoped notifications, and other management capabilities that make sense at a higher organizational level.

## When to Use Projects

Think of Projects as folders that group related Workspaces together for easier management. If you only have a handful of workspaces, projects might feel like overkill, but they become invaluable as you scale to dozens or hundreds of workspaces across multiple teams.

## Implementation Guide

## Core Principles

**Projects** = Organizational boundaries for grouping related infrastructure

**Workspaces** = Individual Terraform state management units (one state file per workspace)

### Project Structure Patterns

#### Pattern 1: Environment-Based (Simple Organizations)
```
Project: Production Infrastructure
  ├── Workspace: prod-networking
  ├── Workspace: prod-database
  └── Workspace: prod-application

Project: Development Infrastructure
  ├── Workspace: dev-networking
  ├── Workspace: dev-database
  └── Workspace: dev-application
```

#### Pattern 2: Application/Service-Based (Recommended for Most)
```
Project: Platform Services
  ├── Workspace: platform-prod
  ├── Workspace: platform-staging
  └── Workspace: platform-dev

Project: E-commerce Application
  ├── Workspace: ecommerce-prod
  ├── Workspace: ecommerce-staging
  └── Workspace: ecommerce-dev
```

#### Pattern 3: Team-Based (Large Organizations)
```
Project: Platform Engineering Team
  ├── Workspace: shared-vpc-prod
  ├── Workspace: shared-vpc-dev
  └── Workspace: kubernetes-clusters

Project: Data Engineering Team
  ├── Workspace: data-pipeline-prod
  └── Workspace: data-pipeline-dev
```

### Decision Framework

#### Use Projects to separate:
- Different teams or ownership boundaries
- Different applications or major services
- Different compliance/security zones
- Infrastructure that requires different access controls

#### Use Workspaces to separate:
- Different environments (prod, staging, dev)
- Different regions for the same service
- Different deployment instances of the same infrastructure pattern

### Naming Conventions

**Projects:** Use clear, descriptive names
- `platform-infrastructure`
- `customer-portal`
- `data-platform`

**Workspaces:** Include environment and purpose
- `{service}-{environment}` (e.g., `api-prod`, `api-staging`)
- `{service}-{region}-{environment}` (e.g., `api-us-east-1-prod`)

### Variable Management

**Project-Level Variable Sets:** Use for values shared across all workspaces
- Cloud provider credentials
- Organization-wide tags
- Common naming prefixes
- Shared service endpoints

**Workspace-Level Variables:** Use for environment-specific values
- Resource sizing (instance types, counts)
- Environment-specific endpoints
- Feature flags
- Region-specific configurations

### Access Control Strategy

1. **Assign teams to Projects**, not individual workspaces
2. Use read-only access for workspaces that serve as data sources
3. Limit write access to production projects
4. Consider separate projects for sensitive infrastructure (compliance, security)

### Anti-Patterns to Avoid

* ❌ One project containing all workspaces (defeats the purpose)
* ❌ One project per workspace (too granular, management overhead)
* ❌ Mixing unrelated infrastructure in the same project
* ❌ Using projects to separate environments (use workspaces instead)

### Quick Reference for AI Assistants

When helping users structure Terraform Cloud:
1. Ask about team structure and ownership boundaries → informs Project design
2. Identify applications/services → each becomes a Project
3. Identify environments/regions → each becomes a Workspace within Projects
4. Group related infrastructure under common ownership in the same Project
5. Default to application-based Projects unless team size or compliance requires team-based structure