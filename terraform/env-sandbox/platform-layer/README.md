# Sandbox Platform Layer

## Purpose

The Platform Layer in Sandbox provides shared platform services for testing:

- EKS clusters (for Kubernetes experimentation)
- RDS databases (test databases)
- ElastiCache (Redis/Memcached for testing)
- Load balancers (ALB/NLB testing)
- Monitoring and logging (CloudWatch, etc.)

## Characteristics

- **Ephemeral**: Can be destroyed and recreated
- **Smaller Scale**: Use smaller instance types than production
- **Cost-Optimized**: Shut down when not in use
- **Testing Focus**: For validating platform patterns

## When to Use

Use this layer to test:

- EKS cluster configurations
- Database migration strategies
- Cache configurations
- Load balancer rules
- Platform service integrations

## Example Structure

```text
platform-layer/
├── eks-test-cluster/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── rds-test-instances/
└── monitoring/
```

## Dependencies

Platform layer depends on Foundation layer:

```bash
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "Datafaced"
    workspaces = {
      name = "sandbox-foundation-iam-roles"
    }
  }
}

# Use foundation outputs
vpc_id     = data.terraform_remote_state.foundation.outputs.vpc_id
subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
```

## Getting Started

1. Ensure Foundation layer is deployed
2. Create directory for your platform component
3. Configure Terraform Cloud workspace
4. Deploy and test

## Best Practices

- Use smallest viable instance sizes
- Tag all resources with `AutoCleanup = "true"`
- Document what you're testing in README
- Clean up when done (or tag for auto-cleanup)
- Consider scheduled shutdowns (e.g., overnight)

## Cost Tips

- Stop RDS instances when not in use
- Use spot instances for EKS nodes
- Delete unused load balancers
- Clean up old AMIs and snapshots
