# Complete Infrastructure Architecture Diagram

## Repository Structure Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       INFRASTRUCTURE MONOREPO                                │
│                    (terraform-infrastructure/)                               │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Layer 01: Foundation (Rarely Changes - Quarterly)                       │ │
│  │ ├── environments/                                                       │ │
│  │ │   ├── dev/          → TF Cloud Workspace: aws-foundation-dev         │ │
│  │ │   ├── staging/      → TF Cloud Workspace: aws-foundation-staging     │ │
│  │ │   └── production/   → TF Cloud Workspace: aws-foundation-production  │ │
│  │ └── Outputs: vpc_id, subnet_ids, security_groups                       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                    ┌──────────┴──────────┐                                  │
│                    ▼                     ▼                                   │
│  ┌────────────────────────────┐ ┌──────────────────────────────────────┐   │
│  │ Layer 02: Platform         │ │ Layer 03: Shared Services            │   │
│  │ (Monthly Changes)          │ │ (Monthly Changes)                    │   │
│  │ ├── environments/          │ │ ├── environments/                    │   │
│  │ │   ├── dev/               │ │ │   ├── dev/                         │   │
│  │ │   ├── staging/           │ │ │   ├── staging/                     │   │
│  │ │   └── production/        │ │ │   └── production/                  │   │
│  │ └── EKS, CI/CD, Monitoring │ │ └── Databases, Caches, Queues        │   │
│  └────────────────────────────┘ └──────────────────────────────────────┘   │
│                    │                     │                                   │
│                    └──────────┬──────────┘                                   │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Layer 04: Applications (Weekly Changes for Scaling/Config)              │ │
│  │ ├── service-a/                                                          │ │
│  │ │   ├── environments/                                                   │ │
│  │ │   │   ├── dev/          → TF Cloud Workspace: aws-service-a-dev      │ │
│  │ │   │   ├── staging/      → TF Cloud Workspace: aws-service-a-staging  │ │
│  │ │   │   └── production/   → TF Cloud Workspace: aws-service-a-prod     │ │
│  │ ├── service-b/                                                          │ │
│  │ │   ├── environments/     (Same structure)                              │ │
│  │ └── service-c/                                                          │ │
│  │     └── environments/     (Same structure)                              │ │
│  │                                                                          │ │
│  │ Note: This defines INFRASTRUCTURE for apps (ECS tasks, scaling, IAM)    │ │
│  │       NOT the application code itself                                   │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      APPLICATION CODE REPOSITORIES                           │
│                        (Separate from Infrastructure)                        │
│                                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐               │
│  │   service-a/   │  │   service-b/   │  │   service-c/   │               │
│  │   ├── src/     │  │   ├── src/     │  │   ├── src/     │               │
│  │   ├── tests/   │  │   ├── tests/   │  │   ├── tests/   │               │
│  │   ├── Docker   │  │   ├── Docker   │  │   ├── Docker   │               │
│  │   └── .github/ │  │   └── .github/ │  │   └── .github/ │               │
│  │       └── CI/CD│  │       └── CI/CD│  │       └── CI/CD│               │
│  └────────────────┘  └────────────────┘  └────────────────┘               │
│         │                   │                   │                            │
│         └───────────────────┴───────────────────┘                            │
│                             │                                                │
│                             ▼                                                │
│            Deploys: Docker images (Daily/Hourly)                            │
│            Infrastructure: ZERO Terraform involvement                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Infrastructure Deployment Flow by Change Type

### Type 1: Application Code Deployment (Daily/Hourly)

```
Developer                     Application Repo               AWS ECS
    │                              │                           │
    │  1. Code change              │                           │
    ├─────────────────────────────►│                           │
    │  git push                    │                           │
    │                              │                           │
    │                              │  2. CI/CD triggered       │
    │                              ├──────────┐                │
    │                              │          │                │
    │                              │  3. Build Docker image    │
    │                              │  4. Push to ECR           │
    │                              │  5. Update ECS task       │
    │                              │          │                │
    │                              │          └───────────────►│
    │                              │                           │
    │                              │  6. Rolling deployment    │
    │  7. Deployment complete      │                           │
    │◄─────────────────────────────┤                           │
    │                              │                           │

Note: ZERO interaction with terraform-infrastructure repo
      Infrastructure stays unchanged
      Terraform not involved at all
```

### Type 2: Application Scaling (Weekly/As Needed)

```
Platform Team           Infra Repo                  Terraform Cloud      AWS
    │                       │                              │              │
    │  1. Update scaling    │                              │              │
    │  parameters           │                              │              │
    ├──────────────────────►│                              │              │
    │  (desired_count,      │                              │              │
    │   cpu, memory)        │                              │              │
    │                       │                              │              │
    │                       │  2. Git push triggers        │              │
    │                       │  webhook                     │              │
    │                       ├─────────────────────────────►│              │
    │                       │                              │              │
    │                       │  3. Terraform plan           │              │
    │                       │                              ├─────────────►│
    │                       │                              │              │
    │                       │  4. Apply (auto in dev/stg,  │              │
    │                       │     manual in prod)          │              │
    │                       │                              ├─────────────►│
    │                       │                              │              │
    │                       │  5. ECS service updated      │              │
    │  6. Notification      │                              │              │
    │◄──────────────────────┴──────────────────────────────┤              │
    │  "Scaling applied"    │                              │              │
```

### Type 3: New Infrastructure Component (Monthly)

```
Platform Team           Infra Repo                  Terraform Cloud      AWS
    │                       │                              │              │
    │  1. Add new service   │                              │              │
    │  infrastructure       │                              │              │
    ├──────────────────────►│                              │              │
    │  (new directory in    │                              │              │
    │   layer 04)           │                              │              │
    │                       │                              │              │
    │                       │  2. PR → Review → Merge      │              │
    │                       │                              │              │
    │                       │  3. Terraform detects new    │              │
    │                       │  workspace needed            │              │
    │                       ├─────────────────────────────►│              │
    │                       │                              │              │
    │                       │  4. Plan & Apply new infra   │              │
    │                       │                              ├─────────────►│
    │                       │                              │  • ECS Task  │
    │                       │                              │  • ALB Rules │
    │                       │                              │  • IAM Roles │
    │                       │                              │  • CloudWatch│
    │                       │                              │              │
    │  5. Infra ready       │                              │              │
    │◄──────────────────────┴──────────────────────────────┤              │
    │                       │                              │              │
    │  6. App team can now deploy code to new service      │              │
    │     (via their app repo CI/CD)                       │              │
```

### Type 4: Foundation Changes (Quarterly)

```
Platform Team           Infra Repo                  Terraform Cloud      AWS
    │                       │                              │              │
    │  1. Major change      │                              │              │
    │  (subnet expansion)   │                              │              │
    ├──────────────────────►│                              │              │
    │  layers/01-foundation/│                              │              │
    │                       │                              │              │
    │                       │  2. Test in dev first        │              │
    │                       ├─────────────────────────────►│              │
    │                       │                              │              │
    │                       │  3. Apply to dev             │              │
    │                       │                              ├─────────────►│
    │                       │                              │              │
    │  4. Validate dev      │                              │              │
    │◄──────────────────────┤                              │              │
    │                       │                              │              │
    │  5. PR to staging     │                              │              │
    ├──────────────────────►│                              │              │
    │                       ├─────────────────────────────►│              │
    │                       │                              ├─────────────►│
    │                       │                              │              │
    │  6. Validate staging  │                              │              │
    │◄──────────────────────┤                              │              │
    │                       │                              │              │
    │  7. PR to production  │                              │              │
    │  (requires 2+         │                              │              │
    │   approvals)          │                              │              │
    ├──────────────────────►│                              │              │
    │                       ├─────────────────────────────►│              │
    │                       │                              │              │
    │  8. Manual approval   │  9. Apply with extreme care  │              │
    │  in TF Cloud UI       │                              ├─────────────►│
    │                       │                              │              │
```

## Layer Dependency Management with terraform_remote_state

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Layer 01: Foundation                                │
│  State: aws-foundation-production                                   │
│                                                                      │
│  outputs.tf:                                                         │
│    output "vpc_id" { value = aws_vpc.main.id }                      │
│    output "private_subnet_ids" { value = [...] }                    │
│    output "security_group_app" { value = aws_sg.app.id }            │
└─────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌────────────────────────────┐  ┌──────────────────────────────────┐
│ Layer 02: Platform         │  │ Layer 03: Shared Services        │
│ State: aws-platform-prod   │  │ State: aws-shared-services-prod  │
│                            │  │                                  │
│ main.tf:                   │  │ main.tf:                         │
│   data "terraform_remote   │  │   data "terraform_remote         │
│     _state" "foundation" { │  │     _state" "foundation" {       │
│     ...                    │  │     ...                          │
│   }                        │  │   }                              │
│                            │  │                                  │
│ outputs.tf:                │  │ outputs.tf:                      │
│   output "ecs_cluster_id"  │  │   output "postgres_endpoint"     │
│   output "monitoring_url"  │  │   output "redis_endpoint"        │
└────────────────────────────┘  └──────────────────────────────────┘
                    │                       │
                    └───────────┬───────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 04: Application - Service A                                   │
│ State: aws-service-a-production                                     │
│                                                                      │
│ main.tf:                                                             │
│   # Get outputs from all dependent layers                           │
│   data "terraform_remote_state" "foundation" {                      │
│     backend = "remote"                                               │
│     config = {                                                       │
│       organization = "your-org"                                      │
│       workspaces = { name = "aws-foundation-production" }           │
│     }                                                                │
│   }                                                                  │
│                                                                      │
│   data "terraform_remote_state" "platform" {                        │
│     backend = "remote"                                               │
│     config = {                                                       │
│       organization = "your-org"                                      │
│       workspaces = { name = "aws-platform-production" }             │
│     }                                                                │
│   }                                                                  │
│                                                                      │
│   data "terraform_remote_state" "shared_services" {                 │
│     backend = "remote"                                               │
│     config = {                                                       │
│       organization = "your-org"                                      │
│       workspaces = { name = "aws-shared-services-production" }      │
│     }                                                                │
│   }                                                                  │
│                                                                      │
│   # Use outputs from other layers                                   │
│   resource "aws_ecs_service" "app" {                                │
│     cluster = data.terraform_remote_state.platform.outputs          │
│                    .ecs_cluster_id                                   │
│                                                                      │
│     network_configuration {                                          │
│       subnets = data.terraform_remote_state.foundation.outputs      │
│                      .private_subnet_ids                             │
│       security_groups = [                                            │
│         data.terraform_remote_state.foundation.outputs              │
│              .security_group_app                                     │
│       ]                                                              │
│     }                                                                │
│                                                                      │
│     environment = [                                                  │
│       {                                                              │
│         name = "DATABASE_HOST"                                       │
│         value = data.terraform_remote_state.shared_services         │
│                      .outputs.postgres_endpoint                      │
│       }                                                              │
│     ]                                                                │
│   }                                                                  │
│                                                                      │
│ outputs.tf:                                                          │
│   output "service_discovery_arn" {                                  │
│     description = "For other services to discover this one"         │
│     value = aws_service_discovery_service.app.arn                   │
│   }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Inter-Service Dependencies

```
┌─────────────────────────────────────────────────────────────────────┐
│ Service A depends on Service B                                       │
└─────────────────────────────────────────────────────────────────────┘

terraform-infrastructure/layers/04-applications/service-a/environments/production/main.tf:

# Service A reads Service B's outputs
data "terraform_remote_state" "service_b" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces = { name = "aws-service-b-production" }
  }
}

resource "aws_ecs_task_definition" "service_a" {
  # Service A can call Service B
  environment = [
    {
      name  = "SERVICE_B_URL"
      value = data.terraform_remote_state.service_b.outputs.service_url
    },
    {
      name  = "SERVICE_B_DISCOVERY"
      value = data.terraform_remote_state.service_b.outputs.service_discovery_arn
    }
  ]
}

# Dependency is explicit and tracked in Terraform
```

## Scaling Strategies Comparison

### Strategy 1: Manual Scaling via Terraform (Good for Permanent Changes)

```
1. Update terraform-infrastructure/layers/04-applications/service-a/
   environments/production/terraform.tfvars:
   
   desired_count = 10  # was 5
   
2. Git commit + push
3. Terraform Cloud auto-plans
4. Manual approval in TF Cloud UI
5. Terraform applies change to ECS
6. New tasks start running

Pros: Changes tracked in git, auditable, repeatable
Cons: Takes 5-10 minutes (PR → review → apply)
```

### Strategy 2: Auto-Scaling (Best for Dynamic Workloads)

```
Define in Terraform once, runs automatically:

resource "aws_appautoscaling_policy" "cpu" {
  target_value = 75.0  # Scale when CPU hits 75%
  predefined_metric_type = "ECSServiceAverageCPUUtilization"
}

resource "aws_appautoscaling_policy" "requests" {
  target_value = 1000.0  # Scale when requests/target hits 1000
  predefined_metric_type = "ALBRequestCountPerTarget"
}

Pros: Fully automated, responds in minutes, handles traffic spikes
Cons: Need to tune thresholds, can cause cost surprises
```

### Strategy 3: Emergency Manual Scaling (Bypass Terraform)

```
For immediate response to incidents:

aws ecs update-service \
  --cluster production-cluster \
  --service service-a \
  --desired-count 20

Tasks start immediately (30-60 seconds)

Then update Terraform to match reality:
1. Update terraform.tfvars: desired_count = 20
2. Commit as "fix: update service-a count to match emergency scaling"
3. Terraform Cloud will show "no changes" (already at 20)

Pros: Immediate effect, no waiting for Terraform
Cons: Creates drift, must sync Terraform afterward
```

### Strategy 4: Scheduled Scaling (For Predictable Patterns)

```
Define in Terraform:

# Scale up for business hours
resource "aws_appautoscaling_scheduled_action" "business_hours" {
  schedule = "cron(0 8 * * MON-FRI *)"  # 8 AM weekdays
  scalable_target_action {
    min_capacity = 10
    max_capacity = 50
  }
}

# Scale down for nights/weekends
resource "aws_appautoscaling_scheduled_action" "off_hours" {
  schedule = "cron(0 20 * * * *)"  # 8 PM daily
  scalable_target_action {
    min_capacity = 2
    max_capacity = 10
  }
}

Pros: Predictable, cost-efficient, no manual intervention
Cons: Need to adjust for holidays, doesn't handle unexpected spikes
```

## Complete Workflow Example: Adding a New Service

```
Step 1: Platform team creates infrastructure
─────────────────────────────────────────────
Repository: terraform-infrastructure
Location: layers/04-applications/service-d/

mkdir -p layers/04-applications/service-d/environments/{dev,staging,production}

# Create main.tf, variables.tf, outputs.tf, terraform.tfvars
# Define ECS task, service, ALB rules, IAM roles, etc.

git commit -m "feat: add service-d infrastructure"
git push

Terraform Cloud creates workspaces and provisions:
- ECS task definition (placeholder image)
- ECS service (0 tasks initially)
- ALB target group and rules
- IAM role for task
- CloudWatch log group
- Service discovery registration

Step 2: Application team creates application
─────────────────────────────────────────────
Repository: service-d/ (NEW separate repo)

# Initialize new application repo
mkdir service-d
cd service-d

# Add application code
mkdir src tests
# ... develop application ...

# Add Dockerfile
cat > Dockerfile <<EOF
FROM python:3.11-slim
COPY src /app
CMD ["python", "/app/main.py"]
EOF

# Add CI/CD
mkdir -p .github/workflows
cat > .github/workflows/deploy.yaml <<EOF
on: push
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - build Docker image
      - push to ECR
      - update ECS service
EOF

git commit -m "initial commit"
git push

Step 3: First deployment
────────────────────────
CI/CD triggers, builds image, pushes to ECR
Updates ECS task definition with real image
ECS starts tasks (service was at 0, now scales to desired_count)

Service D is now live!

Step 4: Day 2 - Code changes
─────────────────────────────
Developers work in service-d/ repo
Push code → CI/CD deploys automatically
Zero interaction with terraform-infrastructure

Step 5: Week 2 - Scale up
──────────────────────────
Traffic increasing, need more tasks

Option A: Update Terraform
  terraform-infrastructure/layers/04-applications/service-d/
    environments/production/terraform.tfvars
  
  desired_count = 10  # was 5

Option B: Let auto-scaling handle it (already configured)

Option C: Emergency AWS CLI
  aws ecs update-service --service service-d --desired-count 10
```

## Benefits Summary

✅ **Clear Separation**
- Infrastructure changes (Terraform) separate from code deployments (CI/CD)
- Platform team manages infrastructure, app teams manage code
- No confusion about which repo to update

✅ **Reduced Blast Radius**
- Foundation changes don't affect applications directly
- Application changes don't touch shared infrastructure
- Each layer has separate state, no lock contention

✅ **Flexible Deployment**
- Code deploys: Daily/hourly (fast, no Terraform)
- Scaling: Multiple strategies (Terraform, auto-scaling, API)
- Infrastructure: Carefully reviewed and tested

✅ **Scalable**
- Easy to add new services (one directory in infra monorepo)
- Team autonomy (app teams own their repos)
- Platform control (platform team owns infrastructure patterns)

✅ **Manageable**
- Fewer repositories than full multi-repo (1 infra + N apps vs 4 infra + 2N)
- All infrastructure visible in one place
- Clear ownership and dependencies