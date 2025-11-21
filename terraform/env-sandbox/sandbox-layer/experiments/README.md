# Sandbox Layer - Experiments

## Purpose

The Sandbox Layer is **unique to the Sandbox environment**. It's for experiments and learning that don't fit into standard infrastructure patterns.

## What Goes Here

Use this layer for:

- **One-off Experiments**: Testing new AWS services or features
- **Learning Projects**: Personal learning and skill development
- **Proof of Concepts**: Validating new architecture ideas
- **Tool Trials**: Testing new IaC tools or patterns
- **Quick Tests**: Rapid iteration without formal structure
- **Research**: Investigating potential solutions

## What Doesn't Go Here

Don't use this layer for:

- Production-like infrastructure (use standard layers)
- Long-lived test environments (use Applications layer)
- Shared team infrastructure (use Platform layer)
- Standard patterns (create proper modules instead)

## Structure

```bash
sandbox-layer/
└── experiments/
    ├── your-name-service-mesh-test/
    │   ├── main.tf
    │   ├── README.md
    │   └── notes.md
    ├── team-member-lambda-edge/
    │   ├── main.tf
    │   ├── lambda/
    │   └── README.md
    └── poc-event-driven-architecture/
        ├── main.tf
        ├── README.md
        └── results.md
```

## Naming Convention

Use descriptive names that include:

- Your name or team
- What you're testing
- Type of experiment

Examples:

- `john-apprunner-evaluation`
- `platform-team-service-mesh-poc`
- `jane-terraform-cdktf-trial`
- `learning-step-functions`

## Required Files

### README.md

Every experiment must have a README:

```markdown
# Experiment: [Name]

**Owner**: Your Name  
**Started**: 2025-11-17  
**Expected Duration**: 3 days  
**Status**: In Progress

## Purpose

What are you testing or learning?

## Resources

What AWS resources are you using?

- ECS Cluster
- ALB
- RDS Instance (db.t3.micro)

## Expected Cost

Estimated: $5/day

## Cleanup Plan

Will destroy on 2025-11-20 or tag for auto-cleanup.

## Results

(Fill in when complete)
```

### Tagging

All resources must be tagged:

```bash
default_tags {
  tags = {
    Environment = "Sandbox"
    Layer       = "Experiments"
    Owner       = "your-name"
    Purpose     = "learning-ecs"
    ExpiresOn   = "2025-11-20"
    AutoCleanup = "true"
    MaxLifetime = "3days"
  }
}
```

## Terraform Cloud Workspaces

Create workspaces as needed:

```text
sandbox-experiments-<descriptive-name>
```

Example:

- `sandbox-experiments-john-apprunner`
- `sandbox-experiments-service-mesh-poc`

## Getting Started

### 1. Create Your Experiment Directory

```bash
cd terraform/env-sandbox/sandbox-layer/experiments/
mkdir your-name-experiment-name
cd your-name-experiment-name
```

### 2. Create README.md

```bash
cat > README.md << 'EOF'
# Experiment: [Your Experiment Name]

**Owner**: Your Name
**Started**: $(date +%Y-%m-%d)
**Expected Duration**: X days
**Status**: In Progress

## Purpose
Why are you doing this experiment?

## Resources
What will you create?

## Expected Cost
Estimate based on resources.

## Results
Will update when complete.
EOF
```

### 3. Create Terraform Configuration

```bash
# main.tf
terraform {
  required_version = ">= 1.13.0"
  
  cloud {
    organization = "Datafaced"
    workspaces {
      name = "sandbox-experiments-your-name-experiment"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Environment = "Sandbox"
      Layer       = "Experiments"
      Owner       = "your-name"
      Purpose     = "experiment-description"
      ExpiresOn   = "2025-11-24"  # One week from now
      AutoCleanup = "true"
    }
  }
}

# Your experiment resources here
```

### 4. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 5. Document Results

Update README.md with:

- What you learned
- What worked
- What didn't work
- Recommendations
- Whether to adopt pattern

### 6. Clean Up

```bash
# When done
terraform destroy

# Or commit changes and let auto-cleanup handle it
git add .
git commit -m "experiment: document results for [name]"
git push
```

## Example Experiments

### Example 1: Testing AWS App Runner

```bash
experiments/john-apprunner-evaluation/
├── main.tf
├── README.md
├── app/
│   ├── Dockerfile
│   └── index.js
└── results.md
```

```bash
# main.tf
resource "aws_apprunner_service" "test" {
  service_name = "sandbox-apprunner-test"
  
  source_configuration {
    image_repository {
      image_identifier      = "public.ecr.aws/nginx/nginx:latest"
      image_repository_type = "ECR_PUBLIC"
    }
  }
  
  tags = {
    Experiment = "apprunner-evaluation"
    Owner      = "john"
  }
}
```

### Example 2: Testing Service Mesh

```text
experiments/platform-service-mesh-poc/
├── main.tf
├── README.md
├── istio/
│   ├── install.sh
│   └── config.yaml
└── results.md
```

### Example 3: Learning CDK for Terraform

```text
experiments/jane-cdktf-trial/
├── main.ts
├── package.json
├── README.md
└── notes.md
```

## Experiment Lifecycle

```text
1. Create
   └─> Document purpose in README
   
2. Develop
   └─> Iterate rapidly, take notes
   
3. Test
   └─> Validate hypothesis
   
4. Document
   └─> Record results in README
   
5. Decide
   ├─> Adopt: Create formal module
   ├─> Reject: Document why
   └─> Continue: More testing needed
   
6. Clean Up
   └─> terraform destroy or auto-cleanup
```

## Safeguards

Even in Experiments layer:

- **Cannot** modify account-level settings
- **Cannot** change organization settings
- **Must** tag all resources
- **Should** set expiration dates
- **Should** estimate costs
- **Must** clean up when done

## Sharing Experiments

If your experiment is useful to others:

### 1. Document Well

- Clear README
- Code comments
- Results and learnings

### 2. Present to Team

- Brown bag session
- Documentation update
- Slack summary

### 3. Promote to Module

If pattern is useful:

```text
experiments/john-useful-pattern/
    └─> terraform-modules/useful-pattern/
        └─> Use in Development environment
```

## Cost Management

### Track Your Costs

```bash
# Check costs for your experiment
aws ce get-cost-and-usage \
  --time-period Start=2025-11-17,End=2025-11-24 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Owner \
  --filter file://filter.json
```

### Set Budget Alerts

Create personal budget:

```bash
resource "aws_budgets_budget" "experiment" {
  name         = "sandbox-experiment-${var.owner}"
  budget_type  = "COST"
  limit_amount = "50"  # $50 limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filter {
    name   = "TagKeyValue"
    values = ["Owner$${var.owner}"]
  }
}
```

## Troubleshooting

### Issue: Workspace Creation Fails

**Solution**: Make sure workspace name follows pattern:

- `sandbox-experiments-<descriptive-name>`
- No spaces, use hyphens
- Lowercase only

### Issue: Permission Denied

**Solution**: Use Experiments role:

```bash
# GitHub Actions
role-to-assume: arn:aws:iam::SANDBOX_ACCOUNT:role/terraform-sandbox-experiments-human-role

# Or use SandboxExperimentsAdmin permission set
```

### Issue: Costs Higher Than Expected

**Check**:

1. NAT Gateways (expensive!)
2. Running RDS instances
3. Elastic IPs
4. Data transfer
5. Load balancers

## Best Practices

1. **Start Small**: Begin with minimal resources
2. **Document Early**: Write README before coding
3. **Set Expiration**: Always set `ExpiresOn` date
4. **Check Costs**: Review costs daily
5. **Ask Questions**: Don't struggle alone
6. **Share Learnings**: Help others avoid mistakes
7. **Clean Up**: Don't leave orphaned resources
8. **Use Version Control**: Commit your experiments

## Related Documentation

- [Sandbox Environment README](../../README.md)
- [Experiments Human Role](../foundation-layer/iam-roles-terraform/README.md#experiments-layer-sandbox-specific)
- [Cost Management Guide](../README.md#cost-management)

## Examples Gallery

See successful experiments from others:

```bash
ls experiments/
```

Learn from their:

- README structure
- Tagging strategy
- Cost estimates
- Results documentation
