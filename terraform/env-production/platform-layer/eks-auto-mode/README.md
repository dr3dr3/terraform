# EKS Auto Mode Cluster - Production Platform

This Terraform configuration provisions an EKS Auto Mode cluster in the Production environment.

## Overview

EKS Auto Mode is AWS's fully managed Kubernetes offering that:

- Automatically provisions and scales compute resources
- Manages the Kubernetes control plane
- Handles node lifecycle and upgrades
- Includes built-in observability and security

## Architecture

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                          VPC (10.2.0.0/16)                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Public Subnet   │  │  Public Subnet   │  │  Public Subnet   │           │
│  │   10.2.1.0/24    │  │   10.2.2.0/24    │  │   10.2.3.0/24    │           │
│  │      AZ-a        │  │      AZ-b        │  │      AZ-c        │           │
│  │   [NAT Gateway]  │  │  [NAT Gateway]   │  │  [NAT Gateway]   │           │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Private Subnet  │  │  Private Subnet  │  │  Private Subnet  │           │
│  │   10.2.11.0/24   │  │   10.2.12.0/24   │  │   10.2.13.0/24   │           │
│  │      AZ-a        │  │      AZ-b        │  │      AZ-c        │           │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘           │
├──────────────────────────────────────────────────────────────────────────────┤
│                        EKS Auto Mode Cluster                                 │
│  - Kubernetes version: 1.31                                                  │
│  - Control plane logging enabled                                             │
│  - Secrets encryption (KMS)                                                  │
│  - 3 AZs with HA NAT (maximum resilience)                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

> **Production Configuration**: This production cluster uses 3 AZs with HA NAT
> Gateways for maximum resilience and availability.

## Prerequisites

1. GitHub Actions OIDC role configured (see `env-production/foundation-layer/gha-oidc`)
2. Terraform Cloud workspace configured
3. AWS CLI access for initial verification
4. **Staging cluster tested and validated**

## Key Production Decisions

Before applying this Terraform, review and confirm:

### 1. VPC CIDR Block

- **Default**: `10.2.0.0/16` (65,536 IPs)
- **Pattern**: Development (10.0.0.0/16), Staging (10.1.0.0/16), Production (10.2.0.0/16)
- **Ensure**: No overlap with VPCs you plan to peer with

### 2. Kubernetes Version

- **Default**: `1.31` (latest stable)
- **Requirement**: Same version tested in staging
- **Consider**: Application compatibility verified in lower environments

### 3. Cluster Endpoint Access

- **Default**: Public enabled, Private enabled
- **Security Recommendation**: Consider disabling public access for production
- **If public enabled**: Restrict to corporate IP ranges

### 4. Control Plane Logging

- **Default**: All log types enabled (required for production audit)
- **Retention**: 90 days (adjust based on compliance requirements)
- **Log types**: api, audit, authenticator, controllerManager, scheduler

### 5. Secrets Encryption

- **Default**: Enabled with dedicated KMS key
- **Production**: Required for compliance

### 6. Number of Availability Zones

- **Default**: 3 AZs (maximum availability)
- **Cost**: ~$96/month for 3 NAT Gateways
- **Benefit**: Survives entire AZ failure

### 7. NAT Gateway Strategy

- **Default**: HA NAT Gateway (one per AZ)
- **Cost**: ~$96/month for 3 AZs
- **Benefit**: No single point of failure for egress traffic

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider config and core resources |
| `variables.tf` | Input variables with defaults |
| `outputs.tf` | Exported values for other layers |
| `backend.tf` | Terraform Cloud backend config |
| `vpc.tf` | VPC, subnets, NAT gateways |
| `eks.tf` | EKS cluster and Auto Mode config |
| `iam.tf` | IAM roles for EKS |
| `kms.tf` | KMS key for secrets encryption |

## Usage

### Via GitHub Actions (Recommended)

Push changes to trigger the workflow:

```bash
git add .
git commit -m "feat: add EKS Auto Mode cluster for production"
git push origin main
```

### Local Development (Testing)

```bash
# Configure AWS credentials (assumes OIDC role)
export AWS_ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/github-actions-prod-platform"

# Initialize Terraform
terraform init

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply (with approval)
terraform apply -var-file="terraform.tfvars"
```

## Outputs

After deployment, the following outputs are available:

- `cluster_name`: EKS cluster name
- `cluster_endpoint`: API server endpoint
- `cluster_certificate_authority_data`: CA certificate for kubectl
- `cluster_oidc_issuer_url`: OIDC issuer for IRSA

## Cost Estimate

| Resource | Estimated Monthly Cost |
|----------|----------------------|
| EKS Control Plane | $73 |
| NAT Gateways (3x) | $96 |
| CloudWatch Logs | ~$10-30 (varies) |
| KMS Key | $1 |
| **Total (minimum)** | **~$180/month** |

Note: This excludes compute costs which are based on actual workload usage with Auto Mode.

## Environment Comparison

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| AZs | 2 | 2 | 3 |
| NAT Gateway | Single | HA (per-AZ) | HA (per-AZ) |
| Log Retention | 30 days | 60 days | 90 days |
| Configuration | Cost optimised | Production-like | Full resilience |
| Est. Monthly Cost | ~$111 | ~$143 | ~$180 |

## Production Checklist

Before deploying to production:

- [ ] Staging cluster tested and validated
- [ ] Application workloads tested in staging
- [ ] Backup and disaster recovery plan documented
- [ ] Monitoring and alerting configured
- [ ] Access controls reviewed and approved
- [ ] Security groups and network policies defined
- [ ] Cost estimates reviewed and approved
- [ ] Runbook for common operations created

## Related Documentation

- [ADR-013: GitHub Actions OIDC for EKS](../../../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md)
- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
