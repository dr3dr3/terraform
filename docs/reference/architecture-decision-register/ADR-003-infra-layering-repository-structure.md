# Architecture Decision Record: Infrastructure Layering and Repository Structure

## Status

Approved

## Context

As our infrastructure grows, we need to make strategic decisions about how to organize and manage different types of infrastructure. We're facing several critical questions:

### Types of Infrastructure We Need to Manage

1. **Foundation/Shared Infrastructure**
   - VPCs, networking, subnets, NAT gateways
   - IAM roles and policies
   - Security groups (shared across applications)
   - Shared databases, caches, message queues
   - DNS zones, certificates
   - Changes infrequently (weeks/months)

2. **Application Infrastructure (per microservice)**
   - ECS/EKS clusters, services, task definitions
   - Application-specific databases
   - Load balancers, target groups
   - Auto-scaling configurations
   - Application-specific IAM roles
   - Changes moderately (days/weeks) for scaling
   - Code deployments happen frequently (daily/hourly) without infrastructure changes

3. **Management/Platform Infrastructure**
   - CI/CD infrastructure
   - Monitoring and logging (CloudWatch, Datadog)
   - Backup and disaster recovery
   - Cost management tools
   - Security scanning tools
   - Changes infrequently (weeks/months)

4. **Cross-Cutting Concerns**
   - Dependencies between applications (service A needs service B's endpoint)
   - Shared resources (load balancer serving multiple apps)
   - Environment-specific configurations

### Key Questions

1. **Repository Strategy**: One monorepo for all IaC or separate repositories?
2. **Application Code**: Should application code and infrastructure code be in the same repository?
3. **State Management**: How many state files? How to organize them?
4. **Layering Strategy**: How to organize infrastructure by change frequency and dependencies?
5. **Deployment Coupling**: When does app deployment trigger infrastructure changes?

### Current Situation

- Using Terraform Cloud for state management (ADR-001)
- VCS-driven workflow with mono-branch + directories (ADR-002)
- Microservices architecture (current: 3 services, growing to 10+)
- Separate AWS accounts for Dev, Staging, Production

### Requirements

- Clear separation of concerns by change frequency
- Enable independent deployment of applications
- Support infrastructure changes without application redeployment
- Support application scaling (up/down) as needed
- Manage dependencies between services
- Allow different teams to work on different infrastructure layers
- Minimize blast radius of changes
- Support both automated and manual scaling decisions

## Decision Drivers

- **Change Frequency**: Different infrastructure changes at different rates
- **Blast Radius**: Limit impact of failures
- **Team Structure**: Platform team + multiple application teams
- **Deployment Independence**: Apps deploy frequently, infra changes less so
- **State Lock Contention**: Multiple engineers need to work simultaneously
- **Dependency Management**: Services depend on each other
- **Maintenance Burden**: Balance between organization and operational overhead

## Options Considered

### Option 1: Infrastructure Monorepo with Layered Structure

#### Overview - Option 1

Single repository for all infrastructure code, organized into layers by change frequency and concern.

#### Repository Structure - Option 1

```bash
terraform-infrastructure/  (Infrastructure monorepo)
├── .github/
│   ├── CODEOWNERS
│   └── workflows/
├── modules/                          # Reusable modules
│   ├── vpc/
│   ├── eks-cluster/
│   ├── rds-postgres/
│   ├── application-service/         # Module for app infrastructure on EKS
│   └── load-balancer/
├── layers/
│   ├── 01-foundation/               # Rarely changes
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── terraform.tfvars
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── README.md
│   ├── 02-platform/                 # Infrequent changes
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── README.md
│   ├── 03-shared-services/          # Moderate changes
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── README.md
│   └── 04-applications/             # Frequent changes
│       ├── service-a/
│       │   ├── environments/
│       │   │   ├── dev/
│       │   │   ├── staging/
│       │   │   └── production/
│       │   └── README.md
│       ├── service-b/
│       └── service-c/
└── docs/

# Separate application code repositories
service-a/  (Application monorepo - separate from infra)
├── src/
├── tests/
├── Dockerfile
└── .github/workflows/
    └── deploy.yaml                  # Builds image, updates k8s-manifests repo
```

#### Terraform Cloud Workspaces - Option 1

```bash
# Foundation Layer (3 workspaces)
aws-foundation-dev         -> layers/01-foundation/environments/dev
aws-foundation-staging     -> layers/01-foundation/environments/staging
aws-foundation-production  -> layers/01-foundation/environments/production

# Platform Layer (3 workspaces)
aws-platform-dev           -> layers/02-platform/environments/dev
aws-platform-staging       -> layers/02-platform/environments/staging
aws-platform-production    -> layers/02-platform/environments/production

# Shared Services (3 workspaces)
aws-shared-services-dev    -> layers/03-shared-services/environments/dev
...

# Per-Application (3 workspaces x N applications)
aws-service-a-dev          -> layers/04-applications/service-a/environments/dev
aws-service-a-staging      -> layers/04-applications/service-a/environments/staging
aws-service-a-production   -> layers/04-applications/service-a/environments/production
```

#### Cross-Layer Data Sharing - Option 1

```hcl
# In service-a/environments/dev/main.tf
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = {
      name = "aws-foundation-dev"
    }
  }
}

data "terraform_remote_state" "shared_services" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = {
      name = "aws-shared-services-dev"
    }
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name = "app"
    namespace = "default"
  }
  
  spec {
    selector {
      match_labels = {
        app = "app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "app"
        }
      }
      
      spec {
        container {
          name  = "app"
          image = "app:latest"
        }
      }
    }
  }
}
```

#### Pros - Option 1

- **Clear layering**: Infrastructure organized by change frequency
- **Reduced blast radius**: Changes to foundation don't affect applications
- **Parallel work**: Different teams can work on different layers simultaneously
- **No state lock contention**: Separate state per layer
- **Single source of truth**: All infrastructure in one place
- **Easier module reuse**: Modules shared across all layers
- **Simplified CODEOWNERS**: Clear ownership per directory
- **Better visibility**: See all infrastructure in one place

#### Cons - Option 1

- **More complex structure**: Requires discipline to maintain
- **Cross-layer dependencies**: Must use terraform_remote_state
- **Larger repository**: Single repo grows with all infrastructure
- **Potential for tight coupling**: Easy to accidentally create tight dependencies
- **Initial learning curve**: Team must understand layering concept

---

### Option 2: Multi-Repository Approach (Repo per Layer/Service)

#### Overview - Option 2

Separate Git repositories for each infrastructure layer and application.

#### Repository Structure - Option 2

```bash
# Infrastructure Repositories
terraform-foundation/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
└── modules/

terraform-platform/
├── environments/
└── modules/

terraform-shared-services/
├── environments/
└── modules/

# Application Infrastructure Repositories
service-a-infrastructure/
├── environments/
└── modules/

service-b-infrastructure/
├── environments/
└── modules/

# Application Code Repositories (separate from infra)
service-a/
├── src/
├── Dockerfile
└── k8s/

service-b/
├── src/
└── k8s/
```

#### Pros - Option 2

- **Maximum isolation**: Complete separation between components
- **Granular access control**: Different repos = different permissions
- **Independent versioning**: Each repo has its own release cycle
- **Smaller repositories**: Easier to navigate
- **Clear boundaries**: Physical separation enforces good practices
- **Team autonomy**: Teams own their entire repository

#### Cons - Option 2

- **Many repositories**: 10+ repos for 10 services
- **Complex dependency management**: Cross-repo dependencies harder to track
- **Module versioning overhead**: Must version modules in separate repos
- **Harder to refactor**: Changes spanning multiple repos require coordination
- **CI/CD complexity**: Must manage pipelines across many repos
- **Difficult to see big picture**: Infrastructure spread across repositories

---

### Option 3: Application Code + Infrastructure Co-located

#### Overview - Option 3

Each application repository contains both application code AND its infrastructure code.

#### Repository Structure - Option 3

```bash
service-a/
├── src/                    # Application code
│   ├── api/
│   └── workers/
├── terraform/              # Infrastructure for this service
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   └── modules/
├── k8s/                    # Kubernetes manifests
├── Dockerfile
└── .github/workflows/
    ├── test-and-build.yaml      # For app code
    └── terraform-apply.yaml     # For infrastructure
```

#### Pros - Option 3

- **Co-location**: Everything for one service in one place
- **Single version**: App and infra versioned together
- **Team ownership**: Team owns entire service stack
- **Simplified onboarding**: One repo to understand
- **Easier to see dependencies**: App dependencies = infra dependencies

#### Cons - Option 3

- **Tight coupling**: Hard to change infrastructure without app context
- **No shared infrastructure**: Foundation layer must be separate anyway
- **Deployment complexity**: Must separate app deploys from infra changes
- **Platform team challenges**: Hard for platform team to manage shared infra
- **Code/infra混杂**: Developers must context-switch between concerns

---

### Option 4: Hybrid Approach - Infra Monorepo + App Repos

#### Overview - Option 4

Infrastructure monorepo (Option 1) + separate application code repositories.

#### Structure - Option 4

```bash
# Infrastructure Monorepo
terraform/
├── env-management/
│   └── foundation-layer/
│       ├── iam-roles-for-people/
│       └── iam-roles-for-terraform/
├── env-development/
│   ├── foundation-layer/
│   │   └── iam-roles-terraform/
│   ├── platform-layer/
│   ├── shared-services-layer/
│   └── applications-layer/
│       ├── eks-learning-cluster/
│       ├── service-a/      # Terraform config for namespace, RBAC, HPA
│       └── service-b/
├── env-staging/
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── shared-services-layer/
│   └── applications-layer/
├── env-production/
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── shared-services-layer/
│   └── applications-layer/
└── env-local/
    ├── foundation-layer/
    ├── platform-layer/
    ├── sandbox-layer/
    └── applications-layer/

# Separate App Repos (Code only)
service-a/
├── src/
├── tests/
├── Dockerfile
└── .github/workflows/
    └── deploy.yaml         # Builds image, updates k8s-manifests repo

# K8s Manifests Repo (GitOps)
k8s-manifests/
├── apps/
│   ├── service-a/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       ├── staging/
│   │       └── production/
│   └── service-b/
└── argocd/
    └── applications/
        ├── service-a.yaml
        └── service-b.yaml

service-b/
├── src/
└── ...
```

#### Workflow - Option 4

1. **Infrastructure changes**: Update terraform repo (e.g., `env-development/applications-layer/service-a/`)
2. **Application deployment**:
   - App repo builds Docker image and pushes to registry
   - App CI/CD updates image tag in k8s-manifests repo
   - ArgoCD detects change and syncs to EKS cluster
   - No Terraform needed for code deployment
3. **Scaling**: Can be done in terraform repo (HPA config) OR via kubectl

#### Pros - Option 4

- **Best separation of concerns**: Infrastructure and application cleanly separated
- **Independent deployment cycles**: Apps deploy without touching infra repo
- **Platform team control**: Infrastructure managed centrally
- **Application team focus**: Apps only care about their code
- **Flexible deployment**: Can update app via kubectl/helm without Terraform

#### Cons - Option 4

- **Two repos per service**: More repos to manage
- **Requires coordination**: Infra changes need sync with app teams
- **Scaling split**: Scaling config might be in infrastructure, but triggered by app

---

## Comparison Matrix

| Criterion | Infra Monorepo + Layering | Multi-Repo | App + Infra Co-located | Hybrid (Recommended) |
|-----------|--------------------------|------------|----------------------|----------------------|
| **Repository Count** | 1 infra + N apps | 4 infra + N apps × 2 | N (app + infra together) | 1 infra + N apps |
| **Separation of Concerns** | Good | Excellent | Poor | Excellent |
| **Infrastructure Visibility** | Excellent | Poor | Poor | Excellent |
| **Team Autonomy (App)** | Good | Good | Excellent | Excellent |
| **Platform Team Control** | Excellent | Excellent | Poor | Excellent |
| **Module Reuse** | Excellent | Fair (versioning overhead) | Poor | Excellent |
| **App Deployment Speed** | Good | Good | Good | Excellent |
| **Infra Change Blast Radius** | Good (layered) | Excellent (isolated) | Poor | Good (layered) |
| **Maintenance Overhead** | Low | High | Medium | Low-Medium |
| **Cross-service Dependencies** | Easy (remote state) | Medium (remote state) | Hard | Easy (remote state) |
| **Best For Team Size** | 5-50 | 50+ | 1-5 (startups) | 5-100 |

## Decision

**Recommended:** Option 4 - Hybrid Approach (Infrastructure Monorepo + Separate Application Repositories)

## Rationale

Given your requirements and team structure, the hybrid approach provides the best balance:

### 1. Clean Separation of Concerns

**Infrastructure** (terraform-infrastructure monorepo):

- Foundation, platform, shared services, application infrastructure
- Managed by platform team
- Changes go through careful review process
- Layered to reduce blast radius

**Application Code** (separate repos):

- Source code, tests, Dockerfile
- Managed by application teams
- Deploys frequently without touching infrastructure
- Can update containers without Terraform

### 2. Solves the "Application Deployment vs Infrastructure Change" Problem

Infrastructure can be decoupled by change frequency. In your case:

- **Daily/Hourly**: Application code deployments (Docker image updates)
  - Handled by application CI/CD
  - Updates K8s deployment manifest
  - No Terraform involved
  
- **Weekly/Monthly**: Application scaling (task count, instance size)
  - Handled by Terraform in infrastructure repo
  - OR by auto-scaling policies (set up in Terraform)
  - OR by AWS API/CLI for manual scaling
  
- **Monthly/Quarterly**: Infrastructure changes (new services, networking changes)
  - Handled by Terraform in infrastructure repo
  - Full review and testing process

### 3. Manages Dependencies Effectively

Services can reference shared infrastructure:

```hcl
# In terraform-infrastructure/layers/04-applications/service-a/environments/dev/main.tf

# Get foundation layer outputs
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-foundation-dev" }
  }
}

# Get service-b's outputs (if service-a depends on it)
data "terraform_remote_state" "service_b" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-service-b-dev" }
  }
}

resource "aws_ecs_service" "service_a" {
  # Use VPC from foundation
  network_configuration {
    subnets = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  }
  
  # Service discovery - find service-b
  service_registries {
    registry_arn = data.terraform_remote_state.service_b.outputs.service_discovery_arn
  }
}
```

### 4. Supports Your Growth Path

- **Current**: 3 services → 1 infra repo + 3 app repos = 4 total
- **Future**: 10 services → 1 infra repo + 10 app repos = 11 total
- vs. Multi-repo: 4 infra layers + (10 × 2) = 24 repos

### 5. Enables Team Autonomy with Platform Control

- **Platform Team**: Owns terraform repo
  - Defines modules and patterns
  - Provisions shared infrastructure
  - Creates application infrastructure (EKS clusters, ingress controllers)
  
- **Application Teams**: Own their service repos
  - Deploy code frequently
  - Don't need to understand Terraform for daily work
  - Request infrastructure changes via PRs to infrastructure repo

## Implementation Plan

### Phase 1: Repository Setup (Week 1)

#### Step 1: Create Infrastructure Monorepo

```bash
terraform/
├── terraform-modules/              # Reusable modules
│   ├── vpc/
│   ├── eks-cluster/
│   ├── application-deployment/
│   └── README.md
├── env-management/
│   └── foundation-layer/
│       ├── iam-roles-for-people/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── terraform.tfvars
│       └── iam-roles-for-terraform/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars
├── env-development/
│   ├── foundation-layer/
│   │   └── iam-roles-terraform/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf          # Export VPC ID, subnets, etc.
│   │       └── terraform.tfvars
│   ├── platform-layer/              # CI/CD, monitoring, logging, EKS
│   ├── shared-services-layer/       # Shared databases, caches
│   └── applications-layer/
│       ├── eks-learning-cluster/
│       ├── service-a/
│       ├── service-b/
│       └── service-c/
├── env-staging/
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── shared-services-layer/
│   └── applications-layer/
├── env-production/
│   ├── foundation-layer/
│   ├── platform-layer/
│   ├── shared-services-layer/
│   └── applications-layer/
└── env-local/
    ├── foundation-layer/
    ├── platform-layer/
    ├── sandbox-layer/
    └── applications-layer/
```

#### Step 2: Configure Terraform Cloud Workspaces

Create workspaces for each layer × environment:

```bash
# Management Environment - Foundation Layer
aws-management-foundation-iam-people    (working-dir: env-management/foundation-layer/iam-roles-for-people)
aws-management-foundation-iam-terraform (working-dir: env-management/foundation-layer/iam-roles-for-terraform)

# Development Environment
aws-dev-foundation-iam       (working-dir: env-development/foundation-layer/iam-roles-terraform)
aws-dev-platform             (working-dir: env-development/platform-layer)
aws-dev-shared-services      (working-dir: env-development/shared-services-layer)
aws-dev-app-service-a        (working-dir: env-development/applications-layer/service-a)
aws-dev-app-service-b        (working-dir: env-development/applications-layer/service-b)

# Staging Environment
aws-staging-foundation-iam   (working-dir: env-staging/foundation-layer/iam-roles-terraform)
aws-staging-platform         (working-dir: env-staging/platform-layer)
aws-staging-shared-services  (working-dir: env-staging/shared-services-layer)
aws-staging-app-service-a    (working-dir: env-staging/applications-layer/service-a)

# Production Environment
aws-prod-foundation-iam      (working-dir: env-production/foundation-layer/iam-roles-terraform)
aws-prod-platform            (working-dir: env-production/platform-layer)
aws-prod-shared-services     (working-dir: env-production/shared-services-layer)
aws-prod-app-service-a       (working-dir: env-production/applications-layer/service-a)
```

### Phase 2: Layer 01 - Foundation (Week 2)

#### Deploy Foundation Infrastructure

```hcl
### Phase 2: Foundation Layer (Week 2)

#### Deploy Foundation Infrastructure

```hcl
# env-development/foundation-layer/iam-roles-terraform/main.tf
terraform {
  required_version = "~> 1.6.0"
  cloud {
    organization = "your-org"
    workspaces {
      name = "aws-dev-foundation-iam"
    }
  }
}

module "vpc" {
  source = "../../../terraform-modules/vpc"
  
  environment = "development"
  cidr_block  = "10.0.0.0/16"
}

# env-development/foundation-layer/iam-roles-terraform/outputs.tf
output "vpc_id" {
  description = "VPC ID for use by other layers"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}
```

### Phase 3: Platform Layer (Week 2-3)

#### Deploy Platform Infrastructure

```hcl
# env-development/platform-layer/main.tf
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-foundation-iam" }
  }
}

module "eks_cluster" {
  source = "../../terraform-modules/eks-cluster"
  
  environment = "development"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids  = data.terraform_remote_state.foundation.outputs.private_subnet_ids
}

module "monitoring" {
  source = "../../terraform-modules/monitoring"
  
  environment = "development"
}
```

### Phase 4: Shared Services Layer (Week 3)

#### Deploy Shared Services

```hcl
# env-development/shared-services-layer/main.tf
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-foundation-iam" }
  }
}

module "shared_postgres" {
  source = "../../terraform-modules/rds-postgres"
  
  environment = "development"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids  = data.terraform_remote_state.foundation.outputs.private_subnet_ids
}

module "shared_redis" {
  source = "../../terraform-modules/elasticache-redis"
  
  environment = "development"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids  = data.terraform_remote_state.foundation.outputs.private_subnet_ids
}

output "postgres_endpoint" {
  value = module.shared_postgres.endpoint
  sensitive = true
}

output "redis_endpoint" {
  value = module.shared_redis.endpoint
}
```

### Phase 5: Applications Layer (Week 4)

#### Deploy Application Infrastructure (NOT code)

```hcl
# env-development/applications-layer/service-a/main.tf
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-foundation-iam" }
  }
}

data "terraform_remote_state" "platform" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-platform" }
  }
}

data "terraform_remote_state" "shared_services" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-shared-services" }
  }
}

module "application" {
  source = "../../../terraform-modules/application-deployment"
  
  service_name = "service-a"
  environment  = "development"
  
  # Infrastructure from other layers
  vpc_id             = data.terraform_remote_state.foundation.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  eks_cluster_name   = data.terraform_remote_state.platform.outputs.eks_cluster_name
  
  # Application-specific settings
  container_image    = "service-a:latest"  # Initial placeholder
  container_port     = 8080
  replicas           = 2
  cpu_request        = "250m"
  memory_request     = "512Mi"
  cpu_limit          = "500m"
  memory_limit       = "1Gi"
  
  # Environment variables (references to shared services)
  environment_variables = {
    DATABASE_HOST = data.terraform_remote_state.shared_services.outputs.postgres_endpoint
    REDIS_HOST    = data.terraform_remote_state.shared_services.outputs.redis_endpoint
  }
}

output "service_discovery_arn" {
  description = "Service discovery ARN for other services to find this one"
  value       = module.application.service_discovery_arn
}

output "service_url" {
  description = "URL to access the service"
  value       = module.application.load_balancer_url
}
```

### Phase 6: Application Code Repository Setup (Week 4)

#### Create Application Repository (Separate from Infrastructure)

```bash
service-a/
├── src/
│   ├── main.py
│   └── requirements.txt
├── tests/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── deploy.yaml         # Builds image, updates k8s-manifests repo
└── README.md

# Separate K8s Manifests Repository (GitOps)
k8s-manifests/
├── apps/
│   ├── service-a/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       │   └── kustomization.yaml
│   │       ├── staging/
│   │       │   └── kustomization.yaml
│   │       └── production/
│   │           └── kustomization.yaml
│   └── service-b/
└── argocd/
    └── applications/
        ├── service-a.yaml
        └── service-b.yaml
```

#### Application CI/CD Pipeline (GitHub Actions)

```yaml
# service-a/.github/workflows/deploy.yaml
name: Deploy Application

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push Docker image
        run: |
          docker build -t service-a:${{ github.sha }} .
          docker push $ECR_REGISTRY/service-a:${{ github.sha }}
      
      - name: Update k8s-manifests repo
        run: |
          git clone https://github.com/org/k8s-manifests.git
          cd k8s-manifests
          cd apps/service-a/overlays/production
          kustomize edit set image service-a=$ECR_REGISTRY/service-a:${{ github.sha }}
          git add .
          git commit -m "Update service-a image to ${{ github.sha }}"
          git push
      
      # ArgoCD automatically detects the change and syncs to cluster
```

## Managing Different Infrastructure Change Types

### Type 1: Application Code Deployment (Daily/Hourly)

**What Changes**: Docker image version
**Where**: Application repository (service-a) + k8s-manifests repo
**How**: Application CI/CD updates k8s-manifests, ArgoCD syncs to cluster
**Terraform Involved**: No

```bash
# Developer workflow
git commit -m "feat: new feature"
git push
# GitHub Actions builds image, pushes to ECR, updates k8s-manifests repo
# ArgoCD detects change and deploys to EKS cluster
# Zero interaction with terraform repo
```

### Type 2: Application Scaling (Weekly/As Needed)

**What Changes**: Replica count, CPU, memory
**Where**: terraform repo (env-development/applications-layer/service-a/)
**How**: Update variables, apply Terraform

#### Option A: Manual Scaling via Terraform

```hcl
# env-development/applications-layer/service-a/terraform.tfvars
replicas      = 5  # Scale from 2 to 5
cpu_request   = "500m"  # Increase CPU
memory_request = "1Gi"  # Increase memory
```

```bash
# Changes applied via Terraform Cloud VCS-driven workflow
git commit -m "scale: increase service-a to 5 tasks"
git push
# Terraform Cloud auto-applies (dev), manual approval (prod)
```

#### Option B: Auto-Scaling (Preferred)

```hcl
# Set up Horizontal Pod Autoscaler in Terraform
resource "kubernetes_horizontal_pod_autoscaler_v2" "app_hpa" {
  metadata {
    name      = "service-a-hpa"
    namespace = "default"
  }

  spec {
    min_replicas = 2
    max_replicas = 10

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "service-a"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 75
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# Now scaling happens automatically, no manual intervention
```

#### Option C: Emergency Manual Scaling (No Terraform)

```bash
# For immediate response, bypass Terraform
kubectl scale deployment service-a \
  --replicas=10 \
  -n production

# Then update Terraform to match reality
# (or let Terraform drift detection alert you)
```

### Type 3: New Infrastructure Components (Monthly)

**What Changes**: New service, new database, networking changes
**Where**: terraform repo
**How**: Add new module calls, apply Terraform

```bash
# In terraform repo
cd env-development/applications-layer
mkdir service-d
# Set up new service infrastructure
git commit -m "feat: add service-d infrastructure"
git push
# Terraform Cloud applies new infrastructure
```

### Type 4: Shared Infrastructure Updates (Quarterly)

**What Changes**: VPC, subnet expansion, new region
**Where**: env-development/foundation-layer/
**How**: Careful planning, testing in dev first

```bash
cd env-development/foundation-layer/iam-roles-terraform
# Update foundation code
terraform plan  # Review carefully
git commit -m "feat: add new subnet for expansion"
# PR review → apply to dev → validate → staging → production
```

## Handling Service Dependencies

### Scenario: Service A Depends on Service B

```hcl
# env-development/applications-layer/service-a/main.tf

# Get Service B's outputs
data "terraform_remote_state" "service_b" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-dev-app-service-b" }
  }
}

module "application" {
  source = "../../../terraform-modules/application-deployment"
  
  service_name = "service-a"
  environment  = "development"
  
  # Service A can call Service B
  environment_variables = {
    SERVICE_B_URL = "http://service-b.default.svc.cluster.local:8080"
    SERVICE_B_HOST = data.terraform_remote_state.service_b.outputs.service_hostname
  }
}
```

## Layer Dependency Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│ Foundation Layer (VPC, Networking, IAM)                         │
│ Path: env-{environment}/foundation-layer/                       │
│ State: aws-{env}-foundation-iam                                 │
│ Changes: Rarely (quarterly)                                     │
│ Outputs: vpc_id, subnet_ids, security_group_ids                │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│ Platform Layer               │ │ Shared Services Layer        │
│ (EKS, CI/CD, Monitoring)     │ │ (Databases, Caches, Queues)  │
│ Path: env-{env}/platform-    │ │ Path: env-{env}/shared-      │
│       layer/                 │ │       services-layer/        │
│ State: aws-{env}-platform    │ │ State: aws-{env}-shared-svc  │
│ Changes: Monthly             │ │ Changes: Monthly             │
│ Depends on: Foundation       │ │ Depends on: Foundation       │
└──────────────────────────────┘ └──────────────────────────────┘
                    │                       │
                    └───────────┬───────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ Applications Layer (Service A, B, C, ...)                       │
│ Path: env-{environment}/applications-layer/{service-name}/      │
│ States: aws-{env}-app-service-a, aws-{env}-app-service-b, ...  │
│ Changes: Weekly (for scaling/config)                            │
│ Depends on: Foundation, Platform, Shared Services, Other Apps   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                                │
                                └
┌─────────────────────────────────────────────────────────────────┐
│ Application Code (Separate Repos)                               │
│ Repos: service-a/, service-b/, service-c/                       │
│ Changes: Daily/Hourly (code deployments)                        │
│ Builds: Docker images, pushes to registry                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                └
┌─────────────────────────────────────────────────────────────────┐
│ K8s Manifests Repository (GitOps)                               │
│ Repo: k8s-manifests/                                            │
│ Changes: Updated by app CI/CD pipelines                         │
│ Contains: Kustomize overlays per environment                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                └ ArgoCD watches and syncs
                                └
┌─────────────────────────────────────────────────────────────────┐
│ EKS Cluster (Running Applications)                              │
│ Deployed by: ArgoCD (GitOps)                                    │
│ No manual kubectl or Terraform for app deployments              │
└─────────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

- **Clear separation**: Infrastructure changes separate from code deployments
- **Reduced state lock contention**: Multiple teams work on different layers
- **Faster app deployments**: Code deploys via ArgoCD GitOps without Terraform
- **Platform control**: Platform team manages shared infrastructure centrally
- **Application autonomy**: App teams focus on code, not infrastructure
- **Scalable**: Easy to add new services without restructuring
- **Manageable complexity**: Fewer repositories than full multi-repo
- **Better visibility**: All infrastructure in one place for platform team
- **GitOps benefits**: Declarative deployments, audit trail, easy rollbacks

### Negative

- **Learning curve**: Team must understand layering concept
- **Cross-layer coordination**: Changes spanning layers need coordination
- **terraform_remote_state**: Must manage cross-layer references
- **Two repos per service**: App repo + infra definition in monorepo

### Neutral

- **Deployment split**: Infrastructure and application have different pipelines
- **Scaling can be done multiple ways**: Terraform, auto-scaling, or API

## Migration Path

### For Existing Infrastructure

1. **Week 1-2**: Organize infrastructure monorepo with env-based layer structure
2. **Week 3**: Import existing infrastructure into appropriate environment/layer directories
3. **Week 4**: Set up Terraform Cloud workspaces per environment and layer
4. **Week 5**: Create k8s-manifests repository and set up ArgoCD
5. **Week 6**: Separate application code from infrastructure
6. **Week 7**: Update application CI/CD to use GitOps workflow

### For New Services

1. Create application infrastructure in `env-{environment}/applications-layer/{service-name}/`
2. Create separate application code repository
3. Add K8s manifests to k8s-manifests repo
4. Configure ArgoCD application
5. Application CI/CD updates manifests, ArgoCD deploys

## Scaling Strategy

### Manual Scaling

```bash
# Option 1: Update Terraform (recommended for permanent changes)
# In env-production/applications-layer/service-a/terraform.tfvars
replicas = 10

# Option 2: kubectl (for temporary emergency scaling)
kubectl scale deployment service-a --replicas=10 -n production
```

### Auto-Scaling (Recommended)

```hcl
# Define in Terraform, runs automatically
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name = "service-a-hpa"
  }

  spec {
    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 75
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    metric {
      type = "Pods"
      pods {
        metric {
          name = "http_requests_per_second"
        }
        target {
          type          = "AverageValue"
          average_value = "1000"
        }
      }
    }
  }
}
```

### Scheduled Scaling

```hcl
# Scale up during business hours
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "scale-up-business-hours"
  service_namespace  = "ecs"
  resource_id        = "service/cluster/service-a"
  scalable_dimension = "ecs:service:DesiredCount"
  schedule           = "cron(0 8 * * MON-FRI *)"  # 8 AM weekdays
  
  scalable_target_action {
    min_capacity = 5
    max_capacity = 20
  }
}

# Scale down after hours
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "scale-down-after-hours"
  schedule           = "cron(0 18 * * MON-FRI *)"  # 6 PM weekdays
  
  scalable_target_action {
    min_capacity = 2
    max_capacity = 5
  }
}
```

## Review Date

This decision should be reviewed in 6 months (April 2026) or when:

- Number of services exceeds 20
- Team grows beyond 20 engineers
- Cross-layer dependencies become unmanageable
- Need for even more granular repository separation emerges

## References

- [Terraform Layering Best Practices (Theodo)](https://cloud.theodo.com/en/blog/terraform-iac-multi-layering)
- [Terraform Monorepo vs Multi-repo (HashiCorp)](https://www.hashicorp.com/en/blog/terraform-mono-repo-vs-multi-repo-the-great-debate)
- [Terraform Layered Architecture (Terrateam)](https://terrateam.io/blog/terraform-deployment-with-layered-architecture)
- [Spacelift Terraform Monorepo Guide](https://spacelift.io/blog/terraform-monorepo)
- ADR-001: Terraform State Management Backend
- ADR-002: Terraform Workflow - Git Branching, CI/CD, and Terraform Cloud Setup

---

## Document Information

- **Created**: October 28, 2025
- **Author**: Platform Engineering Team
- **Reviewers**: [To be assigned]
- **Status**: Pending Review
- **Version**: 1.0
