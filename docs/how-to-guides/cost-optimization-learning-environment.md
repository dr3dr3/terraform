# Cost Optimization for Platform Engineering Learning Environment

This guide provides strategies to minimize AWS costs while learning platform engineering patterns with EKS, ArgoCD, and GitOps.

## Overview

Running a full platform engineering stack (EKS clusters across Development, Staging, Production, and Sandbox) can cost $400-500+/month. For solo learners or small teams experimenting with infrastructure patterns, this guide shows how to reduce costs to **$3-20/month** while still gaining production-relevant experience.

## Cost Baseline: What EKS Actually Costs

### Per-Environment Monthly Costs

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| EKS Control Plane | $73 | Fixed cost, runs 24/7 |
| NAT Gateway (1x) | $32 | Plus data processing charges |
| KMS Key | $1 | Per key for secrets encryption |
| CloudWatch Logs | $5-20 | Depends on log volume |
| VPC Resources | $0 | Subnets, IGW, route tables are free |
| IAM Resources | $0 | Roles, policies are free |
| Elastic IPs | $0-3.60 | Free if attached; ~$3.60/mo if idle |
| Compute (Auto Mode) | Variable | Pay per workload |
| **Total per Environment** | **~$111-130/mo** | Before running workloads |

### Multi-Environment Projections

| Scenario | Monthly Cost | Annual Cost |
|----------|--------------|-------------|
| All 4 environments 24/7 | $440-520 | $5,280-6,240 |
| Single environment 24/7 | $110-130 | $1,320-1,560 |
| Ephemeral (on-demand) | $3-20 | $36-240 |

## Strategy 1: Ephemeral Environment Pattern (Recommended)

The most cost-effective approach for learning: **Provision → Learn → Destroy → Repeat**

### How It Works

```text
┌─────────────────────────────────────────────────────────────┐
│  Learning Session Lifecycle                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Start Session]                                            │
│       │                                                     │
│       ▼                                                     │
│  terraform apply (EKS + ArgoCD)  ──► ~15-20 min            │
│       │                                                     │
│       ▼                                                     │
│  [Learn/Experiment]              ──► Hours/Days             │
│       │                                                     │
│       ▼                                                     │
│  terraform destroy               ──► ~10-15 min            │
│       │                                                     │
│       ▼                                                     │
│  [Session End - $0 running cost]                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Cost Calculation

For 20 hours of learning per month:

- EKS: $73 × (20/730 hours) = ~$2
- NAT: $32 × (20/730 hours) = ~$0.88
- **Total: ~$3-5/month** (vs $110+/month always-on)
- **Savings: ~97%**

### Quick Start Commands

```bash
# Start a learning session
cd terraform/env-development/platform-layer/eks-auto-mode
terraform apply -auto-approve

# Verify cluster is ready
aws eks update-kubeconfig --name dev-eks-auto --region us-east-1
kubectl get nodes

# ... learn for a few hours ...

# ALWAYS destroy when done
terraform destroy -auto-approve
```

### Important Reminders

1. **Always run `terraform destroy`** when you finish learning
2. Set a calendar reminder or timer to avoid forgetting
3. Check AWS Cost Explorer periodically to catch forgotten resources

## Strategy 2: Single Shared Learning Environment

Instead of provisioning all four environments, use **only Development** for learning:

```text
Traditional Approach:           Cost-Optimized Approach:
┌─────────────────┐             ┌─────────────────┐
│ Development EKS │             │ Development EKS │ ◄── All learning here
│ Staging EKS     │             │                 │
│ Production EKS  │   ══►       │ (Other envs     │
│ Sandbox EKS     │             │  exist as code  │
└─────────────────┘             │  but not        │
     $440+/mo                   │  provisioned)   │
                                └─────────────────┘
                                    $110/mo (always-on)
                                    $3-5/mo (ephemeral)
```

### Benefits

- Learn production-like patterns on one cluster
- Test multi-environment concepts via namespaces and ArgoCD projects
- Keep other environment Terraform code ready for "real" deployment
- Demonstrate full multi-env setup when needed (interviews, demos)

## Strategy 3: Scheduled Provisioning

For regular learning schedules, automate cluster lifecycle:

### GitHub Actions: Scheduled Destroy

```yaml
# .github/workflows/scheduled-destroy.yaml
name: Destroy EKS After Hours

on:
  schedule:
    - cron: '0 22 * * *'  # 10 PM UTC daily
  workflow_dispatch:      # Manual trigger

jobs:
  destroy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        working-directory: terraform/env-development/platform-layer/eks-auto-mode
        run: terraform init

      - name: Terraform Destroy
        working-directory: terraform/env-development/platform-layer/eks-auto-mode
        run: terraform destroy -auto-approve
```

### GitHub Actions: Scheduled Provision

```yaml
# .github/workflows/scheduled-apply.yaml
name: Provision EKS Morning

on:
  schedule:
    - cron: '0 8 * * 1-5'  # 8 AM UTC weekdays
  workflow_dispatch:

jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        working-directory: terraform/env-development/platform-layer/eks-auto-mode
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform/env-development/platform-layer/eks-auto-mode
        run: terraform apply -auto-approve
```

### Cost Impact

Running 12 hours/day, 5 days/week:

- ~$25-30/month (vs $110+/month always-on)

## Strategy 4: Use LocalStack for Free Learning

LocalStack simulates AWS services locally—perfect for learning Terraform syntax without any AWS costs.

### Learning Progression

| Tier | Use Case | Tool | Cost |
|------|----------|------|------|
| **Tier 1** | Terraform syntax, modules, patterns | LocalStack | $0 |
| **Tier 2** | Quick AWS validation | Ephemeral EKS (2-4 hours) | $0.50-1 |
| **Tier 3** | ArgoCD, GitOps, full stack | Ephemeral EKS (full day) | $3-5 |
| **Tier 4** | Multi-day integration work | Scheduled EKS (weekdays) | $25-30/mo |

### What LocalStack Can Validate (Free)

- Terraform syntax and structure
- Module composition
- Resource relationships
- IAM policy documents
- VPC configuration
- Basic EKS cluster definition

### What Requires Real AWS (Paid)

- Actual Kubernetes API behavior
- ArgoCD and GitOps workflows
- IRSA (IAM Roles for Service Accounts)
- Real networking behavior
- Load balancer provisioning
- Production-like validation

### Using LocalStack

```bash
# Start LocalStack (requires Docker)
cd /workspace
docker compose -f docker-compose.localstack.yml up -d

# Run Terraform against LocalStack
cd terraform/env-local/applications-layer/eks-learning-cluster
terraform init
terraform plan
terraform apply

# Clean up
terraform destroy
docker compose -f docker-compose.localstack.yml down
```

## Strategy 5: Architecture Optimizations

Reduce per-environment costs with these Terraform changes:

### 5a. Disable CloudWatch Logs Until Needed

Edit `terraform/env-development/platform-layer/eks-auto-mode/variables.tf`:

```hcl
variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = []  # Empty = no logs = $0
  # Enable when debugging: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
```

**Savings**: $5-20/month

### 5b. Use VPC Endpoints Instead of NAT Gateway

For learning environments where you only need AWS service access (not general internet):

```hcl
# Replace NAT Gateway with VPC Endpoints
resource "aws_vpc_endpoint" "eks" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.eks"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}
```

**Savings**: ~$32/month (NAT Gateway cost)

**Trade-off**: More complex setup, only works for AWS services

### 5c. Single NAT Gateway (Already Configured)

Your current setup uses `single_nat_gateway = true`, which saves ~$32/month compared to one NAT per AZ.

## Monitoring Costs

### AWS Cost Explorer CLI

```bash
# Check yesterday's costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Check month-to-date
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### Set Up Budget Alerts

```hcl
# Add to your Terraform configuration
resource "aws_budgets_budget" "learning" {
  name              = "learning-environment-budget"
  budget_type       = "COST"
  limit_amount      = "50"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["your-email@example.com"]
  }
}
```

## Recommended Workflow for Solo Learner

### Daily Practice (Free - $0)

1. Write Terraform code in VS Code
2. Validate syntax with `terraform validate`
3. Test against LocalStack for basic resources
4. Review documentation and plan next learning session

### Weekly AWS Sessions ($5-10/week)

1. **Morning**: Run `terraform apply` for EKS (~15-20 min)
2. **Day**: Deploy ArgoCD, test GitOps patterns, experiment
3. **Evening**: Run `terraform destroy` before stopping

### Monthly Rhythm

| Week | Focus | AWS Cost |
|------|-------|----------|
| Week 1 | EKS basics, kubectl, namespaces | $3-5 |
| Week 2 | ArgoCD setup, App of Apps | $3-5 |
| Week 3 | GitOps workflows, Helm charts | $3-5 |
| Week 4 | IRSA, observability, cleanup | $3-5 |
| **Total** | | **$12-20/month** |

## Quick Reference: Cost Comparison

| Approach | Monthly Cost | Best For |
|----------|--------------|----------|
| All 4 envs 24/7 | $440+ | Production orgs |
| Single env 24/7 | $110+ | Full-time platform teams |
| Scheduled (12h/day, weekdays) | $25-30 | Daily learners |
| Ephemeral (on-demand) | $3-20 | Weekly/weekend learners |
| LocalStack only | $0 | Terraform syntax practice |

## Checklist: Before Ending a Session

- [ ] Run `terraform destroy` for any provisioned environments
- [ ] Verify in AWS Console that EKS cluster is terminated
- [ ] Check for orphaned resources (NAT Gateways, Elastic IPs, EBS volumes)
- [ ] Review Cost Explorer for unexpected charges

## Related Documentation

- [ADR-011: Sandbox Environment](../reference/architecture-decision-register/ADR-011-sandbox-environment.md) - Sandbox environment design
- [ADR-012: Automated Cleanup](../reference/architecture-decision-register/ADR-012-sandbox-automated-cleanup.md) - Automated resource cleanup
- [ADR-018: ArgoCD Bootstrapping](../reference/architecture-decision-register/ADR-018-argocd-bootstrapping.md) - GitOps bootstrap pattern
- [LocalStack Setup](localstack-setup.md) - Using LocalStack for local testing
- [EKS Auto Mode README](../../terraform/env-development/platform-layer/eks-auto-mode/README.md) - EKS cluster configuration
