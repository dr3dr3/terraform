# ADR-013: GitHub Actions OIDC Authentication for EKS Provisioning

## Status

Approved  

## Context

We have a multi-account AWS setup (Development, Staging, Production) with Terraform workspaces layered as foundation, platform, and application. State is managed in Terraform Cloud.

We need a secure mechanism for GitHub Actions to provision infrastructure (specifically EKS Auto Mode clusters) in the development-platform workspace without storing long-lived AWS credentials.

## Decision

Use OIDC federation between GitHub Actions and AWS IAM to allow short-lived credential assumption for Terraform operations.

### Architecture

- **Roles workspace** (VCS-driven in Terraform Cloud): Creates IAM roles including the GitHub Actions execution role
- **Development-platform workspace** (GitHub Actions-driven): Assumes the role to provision EKS

### Implementation

#### 1. GitHub OIDC Provider

Create in the roles workspace (or foundation layer if shared):

| Setting | Value |
|---------|-------|
| URL | `https://token.actions.githubusercontent.com` |
| Client ID | `sts.amazonaws.com` |
| Thumbprint | `ffffffffffffffffffffffffffffffffffffffff` |

#### 2. IAM Role

**Name**: `github-actions-dev-platform`

**Trust policy conditions**:

- Audience: `sts.amazonaws.com`
- Subject: `repo:{org}/{repo}:*` (scope to specific repo)

#### 3. Required Permissions

| Category | Actions |
|----------|---------|
| EKS | `eks:*` |
| IAM | CreateRole, DeleteRole, GetRole, PassRole, AttachRolePolicy, DetachRolePolicy, ListAttachedRolePolicies, ListRolePolicies, ListInstanceProfilesForRole, TagRole, UntagRole, CreateOpenIDConnectProvider, DeleteOpenIDConnectProvider, GetOpenIDConnectProvider, TagOpenIDConnectProvider |
| EC2/VPC | CreateVpc, DeleteVpc, DescribeVpcs, ModifyVpcAttribute, CreateSubnet, DeleteSubnet, DescribeSubnets, CreateSecurityGroup, DeleteSecurityGroup, DescribeSecurityGroups, AuthorizeSecurityGroupIngress/Egress, RevokeSecurityGroupIngress/Egress, CreateTags, DeleteTags, DescribeTags, DescribeAvailabilityZones, CreateInternetGateway, DeleteInternetGateway, AttachInternetGateway, DetachInternetGateway, DescribeInternetGateways, CreateRouteTable, DeleteRouteTable, DescribeRouteTables, CreateRoute, DeleteRoute, AssociateRouteTable, DisassociateRouteTable, AllocateAddress, ReleaseAddress, DescribeAddresses, CreateNatGateway, DeleteNatGateway, DescribeNatGateways |
| CloudWatch | CreateLogGroup, DeleteLogGroup, DescribeLogGroups, PutRetentionPolicy, TagLogGroup, ListTagsLogGroup |

#### 4. GitHub Actions Workflow Requirements

- Trigger on push/PR to `main` for paths `environments/development/platform/**`
- Permission: `id-token: write`
- Use `aws-actions/configure-aws-credentials@v4` for role assumption
- Authenticate to Terraform Cloud via `TF_API_TOKEN` secret
- Backend uses Terraform Cloud (no S3/DynamoDB needed)

#### 5. Output

Export `github_actions_dev_platform_role_arn` for workflow configuration.

## Consequences

### Positive

- **No long-lived credentials**: OIDC tokens are short-lived and scoped to workflow runs
- **Auditable**: CloudTrail logs show which repo/workflow assumed the role
- **Scalable pattern**: Same approach extends to staging/production with separate roles
- **Separation of concerns**: Role definition (roles workspace) is decoupled from role usage (platform workspace)

### Negative

- **Additional IAM complexity**: OIDC provider and trust policies require careful configuration
- **Debugging difficulty**: OIDC trust failures can be opaque; requires checking conditions carefully

### Risks

- **Overly permissive trust policy**: Must scope subject condition to specific repos/branches
- **Permission creep**: IAM permissions should be reviewed and tightened for production

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|-----------------|
| IAM user with access keys | Security risk; long-lived credentials stored in GitHub secrets |
| Terraform Cloud dynamic credentials | Would require all workspaces to be TFC-driven; limits flexibility |
| AWS CodePipeline/CodeBuild | Additional AWS service complexity; team prefers GitHub Actions |

## Related Decisions

- EKS cluster IAM roles (cluster role, IRSA) will be provisioned in the development-platform workspace alongside the cluster
- Staging and production will follow the same pattern with environment-specific roles

## Document Information

**Date**: 2025-05-28  
**Deciders**: Platform Engineering Team
