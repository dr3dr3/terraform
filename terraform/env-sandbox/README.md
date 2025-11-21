# Sandbox Environment

## Purpose

The Sandbox environment is a dedicated AWS account for testing, experimentation, and learning. It provides a safe space to:

- Test new Terraform configurations before applying to Development
- Experiment with new AWS services and architectures
- Run automated integration tests for Terraform modules
- Learn and practice infrastructure-as-code techniques
- Trial new tools and patterns without risk to other environments

## Key Characteristics

### Isolation

- **Separate AWS Account**: Complete isolation from Development, Staging, and Production
- **No Production Data**: No real customer data or production workloads
- **Ephemeral Resources**: Resources can be destroyed and recreated frequently
- **Cost Controls**: Spending limits and automated cleanup

### Flexibility

- **Broader Permissions**: More permissive IAM roles for experimentation
- **Experiments Layer**: Special layer for ad-hoc testing that doesn't fit standard patterns
- **Rapid Iteration**: Faster feedback loops without extensive approvals
- **Learning Environment**: Safe space for team members to learn

### Automation

- **Automated Cleanup**: Resources tagged for automatic cleanup after specified lifetime
- **Cost Alerts**: Notifications when spending exceeds thresholds
- **Resource Limits**: Service quotas to prevent runaway costs
- **Scheduled Cleanup**: Regular cleanup of old resources (e.g., weekly)

## Environment Structure

```text
env-sandbox/
├── foundation-layer/
│   └── iam-roles-terraform/      # IAM roles for Terraform execution
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── platform-layer/                # EKS, RDS, shared infrastructure (for testing)
├── applications-layer/            # Test applications
└── sandbox-layer/                 # Experimental and learning resources
    └── experiments/               # Ad-hoc experiments that don't fit standard layers
```

## Layer Descriptions

### Foundation Layer

Standard networking, security groups, and IAM setup - same as other environments but with:

- More permissive security groups for testing
- Additional IAM roles for experimentation
- Test VPCs and subnets

### Platform Layer

Platform services for testing:

- Test EKS clusters
- Test RDS instances (smaller, ephemeral)
- Test caches and queues
- Monitoring and logging setup

### Applications Layer

Test application deployments:

- Sample applications for testing deployment patterns
- Integration test applications
- Performance test workloads

### Sandbox Layer (Unique to Sandbox)

Special layer for experiments that don't fit standard patterns:

- One-off AWS service trials
- Architecture experiments
- Learning projects
- Proof-of-concept implementations
- Testing new Terraform patterns

## Terraform Cloud Workspaces

```text
sandbox-foundation-iam-roles       → env-sandbox/foundation-layer/iam-roles-terraform/
sandbox-platform                   → env-sandbox/platform-layer/
sandbox-app-*                      → env-sandbox/applications-layer/*/
sandbox-experiments-*              → env-sandbox/sandbox-layer/experiments/*/
```

## IAM Roles

### Foundation Roles

- `terraform-sandbox-foundation-cicd-role`: For CI/CD pipelines
- `terraform-sandbox-foundation-human-role`: For human operators
- `SandboxFoundationAdmin` permission set: IAM Identity Center access

### Platform Roles

- `terraform-sandbox-platform-cicd-role`: For CI/CD pipelines
- `terraform-sandbox-platform-human-role`: For human operators
- `SandboxPlatformAdmin` permission set: IAM Identity Center access

### Application Roles

- `terraform-sandbox-application-cicd-role`: For CI/CD pipelines
- `terraform-sandbox-application-human-role`: For human operators
- `SandboxApplicationAdmin` permission set: IAM Identity Center access

### Experiments Roles (Sandbox-Specific)

- `terraform-sandbox-experiments-human-role`: Broad permissions for experimentation
- `SandboxExperimentsAdmin` permission set: PowerUser + additional permissions

**Note**: Experiments roles have broader permissions but with safeguards:

- Cannot modify account-level settings
- Cannot change organization settings
- Tagged for audit trail
- Time-limited sessions (12 hours)

## Getting Started

### 1. Prerequisites

- AWS Sandbox account created
- OIDC provider configured in Sandbox account
- IAM Identity Center group for sandbox access
- Terraform Cloud organization access

### 2. Update Configuration

```bash
cd terraform/env-sandbox/foundation-layer/iam-roles-terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Sandbox account details
```

### 3. Deploy Foundation Layer

```bash
# This will be done via Terraform Cloud VCS-driven workflow
git add .
git commit -m "feat: add sandbox environment foundation layer"
git push
```

### 4. Create Additional Layers

After foundation layer is deployed, create platform, applications, and sandbox layers as needed.

## Resource Tagging Strategy

All resources in Sandbox should be tagged with:

```hcl
tags = {
  Environment  = "Sandbox"
  ManagedBy    = "Terraform"
  AutoCleanup  = "true"
  MaxLifetime  = "7days"     # Or appropriate value
  Owner        = "team-name"  # Who created it
  Purpose      = "testing"    # Or "learning", "experiment", etc.
  ExpiresOn    = "2025-11-24" # Explicit expiration date
}
```

## Automated Cleanup

### AWS Nuke Configuration

See [TODO: Create AWS Nuke setup] for automated cleanup configuration.

Planned cleanup strategy:

- **Daily**: Remove resources older than `MaxLifetime` tag
- **Weekly**: Full cleanup of untagged resources
- **Manual**: On-demand cleanup for specific experiments

### Resource Protection

To prevent cleanup of long-lived test resources:

```hcl
tags = {
  AutoCleanup  = "false"
  Protected    = "true"
  Reason       = "Long-term integration test environment"
}
```

## Cost Management

### Spending Limits

- **Budget Alert**: $500/month (adjust as needed)
- **Emergency Threshold**: $1000/month (immediate alert)
- **Cost Allocation Tags**: Track spending by team, purpose, layer

### Cost Optimization

- Use smallest instance types for testing
- Shut down resources when not in use
- Use spot instances where possible
- Schedule resources (e.g., RDS stop overnight)
- Regular cleanup of orphaned resources

## Best Practices

### 1. Always Tag Resources

```hcl
default_tags {
  tags = {
    Environment = "Sandbox"
    ManagedBy   = "Terraform"
    AutoCleanup = "true"
    Owner       = var.team_name
  }
}
```

### 2. Use Short Lifetimes

- Default to 7 days for experiments
- Extend only if needed
- Document why longer lifetime is required

### 3. Clean Up After Yourself

```bash
# Destroy resources when done
terraform destroy

# Or tag for automated cleanup
# AutoCleanup = "true", MaxLifetime = "24hours"
```

### 4. Document Experiments

Create a README in `sandbox-layer/experiments/<your-experiment>/`:

```markdown
# Experiment: [Name]

## Purpose
What are you testing?

## Expected Duration
How long will this run?

## Resources
What AWS resources are being used?

## Results
What did you learn?
```

### 5. Test Before Development

Flow: Sandbox → Development → Staging → Production

```text
┌─────────┐    ┌─────────────┐    ┌─────────┐    ┌────────────┐
│ Sandbox │ -> │ Development │ -> │ Staging │ -> │ Production │
└─────────┘    └─────────────┘    └─────────┘    └────────────┘
    ↑                                                     
    └── Test here first!
```

### 6. Protect Sensitive Data

- **NO PRODUCTION DATA** in Sandbox
- Use synthetic test data only
- No real customer information
- No production API keys or secrets

## Testing Workflows

### Unit Testing Terraform Modules

```bash
# In terraform-modules/vpc/ directory
cd terraform-modules/vpc/
terraform init
terraform plan \
  -var="environment=sandbox" \
  -var="vpc_cidr=10.99.0.0/16"
```

### Integration Testing

```bash
# Deploy full stack in Sandbox
cd terraform/env-sandbox/applications-layer/test-app/
terraform init
terraform apply  # Test the full deployment

# Run tests
./run-integration-tests.sh

# Clean up
terraform destroy
```

### Automated Testing in CI/CD

```yaml
# .github/workflows/test-terraform.yaml
name: Test Terraform

on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::SANDBOX_ACCOUNT_ID:role/terraform-sandbox-experiments-human-role
          aws-region: us-east-1
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Plan
        run: terraform plan
      
      - name: Deploy to Sandbox
        run: terraform apply -auto-approve
      
      - name: Run Tests
        run: ./run-tests.sh
      
      - name: Cleanup
        if: always()
        run: terraform destroy -auto-approve
```

## Troubleshooting

### Issue: Resources Not Being Cleaned Up

**Check**:

1. Tags are correct: `AutoCleanup = "true"`
2. AWS Nuke is configured and running
3. Resource age is past `MaxLifetime`

### Issue: Permission Denied

**Check**:

1. Using correct IAM role for the layer
2. Permission boundary not blocking action
3. Service quota not exceeded

### Issue: Costs Higher Than Expected

**Check**:

1. Old resources not cleaned up
2. Large instance types being used
3. Resources running 24/7 unnecessarily
4. NAT gateways (expensive!)
5. Data transfer costs

## Related Documentation

- [ADR-009: Folder Structure](../../../docs/reference/architecture-decision-register/ADR-009-folder-structure.md)
- [Guide to Testing Terraform](../../../docs/explanations/guide-to-testing-terraform.md)
- [Terraform Best Practices](../../../docs/to-do/terraform-best-practices.md)

## Support

For questions or issues with Sandbox environment:

1. Check this README
2. Review existing experiments in `sandbox-layer/experiments/`
3. Ask in team Slack channel
4. Create an issue in the repository

## Changelog

- **2025-11-17**: Initial Sandbox environment created
  - Foundation layer IAM roles
  - Directory structure
  - Documentation
