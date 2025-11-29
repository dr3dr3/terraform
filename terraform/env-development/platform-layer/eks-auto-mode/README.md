# EKS Auto Mode Cluster - Development Platform

This Terraform configuration provisions an EKS Auto Mode cluster in the Development environment.

## Overview

EKS Auto Mode is AWS's fully managed Kubernetes offering that:

- Automatically provisions and scales compute resources
- Manages the Kubernetes control plane
- Handles node lifecycle and upgrades
- Includes built-in observability and security

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Public Subnet  │  │  Public Subnet  │  │  Public Subnet  │  │
│  │   10.0.1.0/24   │  │   10.0.2.0/24   │  │   10.0.3.0/24   │  │
│  │      AZ-a       │  │      AZ-b       │  │      AZ-c       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Private Subnet  │  │ Private Subnet  │  │ Private Subnet  │  │
│  │   10.0.11.0/24  │  │   10.0.12.0/24  │  │   10.0.13.0/24  │  │
│  │      AZ-a       │  │      AZ-b       │  │      AZ-c       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    EKS Auto Mode Cluster                        │
│  - Kubernetes version: 1.31                                     │
│  - Control plane logging enabled                                │
│  - Secrets encryption (KMS)                                     │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. GitHub Actions OIDC role configured (see `env-management/foundation-layer/github-actions-oidc-role`)
2. Terraform Cloud workspace configured
3. AWS CLI access for initial verification

## Key Decisions Required

Before applying this Terraform, review and confirm:

### 1. VPC CIDR Block

- **Default**: `10.0.0.0/16` (65,536 IPs)
- **Consider**: Will this overlap with other VPCs you might peer with?
- **Recommendation**: Use a unique /16 per environment

### 2. Kubernetes Version

- **Default**: `1.31` (latest stable)
- **Consider**: Application compatibility, team familiarity
- **Recommendation**: Use latest for new clusters

### 3. Cluster Endpoint Access

- **Default**: Public enabled, Private enabled
- **Consider**: Security requirements, where will kubectl run from?
- **Options**:
  - Public only: Easiest, less secure
  - Private only: Most secure, requires VPN/bastion
  - Both: Balanced (default)

### 4. Control Plane Logging

- **Default**: All log types enabled
- **Consider**: Cost implications (CloudWatch Logs charges)
- **Log types**: api, audit, authenticator, controllerManager, scheduler

### 5. Secrets Encryption

- **Default**: Enabled with dedicated KMS key
- **Consider**: Required for compliance, slight latency overhead
- **Recommendation**: Always enable for production path

### 6. Number of Availability Zones

- **Default**: 3 AZs
- **Consider**: Cost (NAT Gateway per AZ), high availability needs
- **Options**:
  - 2 AZs: Lower cost, still HA
  - 3 AZs: Best practice for production

### 7. NAT Gateway Strategy

- **Default**: One NAT Gateway per AZ (high availability)
- **Consider**: Cost (~$32/month per NAT Gateway)
- **Options**:
  - Single NAT: ~$32/month, single point of failure
  - Per-AZ NAT: ~$96/month for 3 AZs, highly available

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
git commit -m "feat: add EKS Auto Mode cluster"
git push origin main
```

### Local Development (Testing)

```bash
# Configure AWS credentials (assumes OIDC role)
export AWS_ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/github-actions-dev-platform"

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
| CloudWatch Logs | ~$5-20 (varies) |
| KMS Key | $1 |
| **Total (minimum)** | **~$175/month** |

Note: This excludes compute costs which are based on actual workload usage with Auto Mode.

## Related Documentation

- [ADR-013: GitHub Actions OIDC for EKS](../../../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md)
- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
