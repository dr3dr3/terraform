# Sandbox Foundation Layer

## Purpose

The Foundation Layer in Sandbox provides core infrastructure for testing:

- VPC and networking (subnets, route tables, NAT gateways)
- IAM roles and policies (for sandbox workloads)
- KMS keys (for encryption testing)
- S3 buckets (for sandbox data storage)
- Security groups (baseline network security)

## Characteristics

- **Ephemeral**: Can be destroyed and recreated
- **Simplified Networking**: Single AZ or minimal HA setup
- **Cost-Optimized**: Use NAT instances instead of NAT gateways
- **Testing Focus**: For validating infrastructure patterns

## When to Use

Use this layer to test:

- VPC and subnet configurations
- IAM role and policy patterns
- KMS key management strategies
- S3 bucket policies and configurations
- Network ACL and security group rules

## Example Structure

```text
foundation-layer/
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── iam-roles/
├── kms-keys/
└── s3-buckets/
```

## Dependencies

Foundation layer is the base layer with no Terraform dependencies:

```bash
# Foundation layer typically has no remote state dependencies
# It provides outputs for other layers to consume

# Example outputs this layer might provide:
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```

## Getting Started

1. Create directory for your foundation component
2. Configure Terraform Cloud workspace
3. Deploy foundation resources
4. Use outputs in Platform and Application layers

## Best Practices

- Use single AZ for cost savings (sandbox only)
- Tag all resources with `AutoCleanup = "true"`
- Use smaller CIDR blocks than production
- Document infrastructure patterns in README
- Consider NAT instances over NAT gateways

## Cost Tips

- Use NAT instances instead of NAT gateways
- Limit to single AZ when possible
- Use VPC endpoints sparingly
- Clean up unused Elastic IPs
- Delete VPCs when not in use (they're free, but attached resources aren't)
