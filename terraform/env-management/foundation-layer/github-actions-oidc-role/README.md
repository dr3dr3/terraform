# GitHub Actions OIDC Role for EKS Provisioning

This Terraform configuration creates the OIDC provider and IAM role for GitHub Actions to provision EKS infrastructure in the development platform layer.

## Architecture

Per [ADR-013](../../../../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md):

- **This workspace (VCS-driven in Terraform Cloud)**: Creates IAM roles including the GitHub Actions execution role
- **Development-platform workspace (GitHub Actions-driven)**: Assumes the role to provision EKS

## Resources Created

| Resource | Description |
|----------|-------------|
| `aws_iam_openid_connect_provider.github_actions` | OIDC provider for GitHub Actions |
| `aws_iam_role.github_actions_dev_platform` | IAM role for EKS provisioning |
| `aws_iam_role_policy.github_actions_dev_platform_permissions` | Permissions policy |

## OIDC Provider Configuration

| Setting | Value |
|---------|-------|
| URL | `https://token.actions.githubusercontent.com` |
| Client ID (Audience) | `sts.amazonaws.com` |
| Thumbprint | `ffffffffffffffffffffffffffffffffffffffff` |

## Trust Policy

The role can only be assumed by GitHub Actions workflows running from the specified repository:

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:{org}/{repo}:*"
    }
  }
}
```

## Permissions

The role includes permissions for:

| Category | Purpose |
|----------|---------|
| EKS | Full EKS cluster management (`eks:*`) |
| IAM | Create/manage EKS cluster roles, node roles, and IRSA OIDC providers |
| EC2/VPC | VPC, subnets, security groups, internet gateways, NAT gateways, route tables |
| CloudWatch | Log group management for EKS control plane logs |
| KMS | Key management for EKS secrets encryption |

## Usage

### Prerequisites

1. AWS credentials configured (for initial deployment)
2. Terraform Cloud workspace created
3. GitHub repository configured

### Deploy

```bash
# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars

# Initialize
terraform init

# Plan and apply
terraform plan
terraform apply
```

### GitHub Actions Workflow

After deployment, use the role ARN in your GitHub Actions workflow:

```yaml
name: Deploy EKS

on:
  push:
    branches: [main]
    paths:
      - 'terraform/env-development/platform-layer/**'

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-southeast-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve
```

## Outputs

| Output | Description |
|--------|-------------|
| `github_actions_oidc_provider_arn` | ARN of the OIDC provider |
| `github_actions_dev_platform_role_arn` | ARN to use in GitHub Actions workflow |
| `github_actions_dev_platform_role_name` | Name of the IAM role |

## Security Considerations

- **Scoped trust policy**: Role can only be assumed by the specified repository
- **No long-lived credentials**: OIDC tokens are short-lived and scoped to workflow runs
- **Auditable**: CloudTrail logs show which repo/workflow assumed the role
- **Least privilege**: Permissions are scoped to EKS-related resources where possible

## Related ADRs

- [ADR-013: GitHub Actions OIDC Authentication for EKS Provisioning](../../../../docs/reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md)

## Future Enhancements

Per ADR-013, staging and production environments will follow the same pattern with:

- `github-actions-staging-platform` role
- `github-actions-prod-platform` role
- Tighter subject conditions (e.g., branch restrictions)
