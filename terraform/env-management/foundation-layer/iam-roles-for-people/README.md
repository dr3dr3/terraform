# IAM Roles for People - IAM Identity Center Configuration

This Terraform configuration creates IAM Identity Center (AWS SSO) groups and permission sets for human users accessing AWS accounts, with a focus on supporting EKS RBAC integration.

## Overview

This module implements a 5-tier user persona model (see [ADR-015](../../../../docs/reference/architecture-decision-register/ADR-015-user-personas-aws-sso-eks.md)) that maps AWS SSO groups to Kubernetes RBAC roles:

| Persona | AWS SSO Group | K8s RBAC Role | Session Duration |
|---------|---------------|---------------|------------------|
| **Administrator** | Administrators | cluster-admin | 4 hours |
| **Platform Engineer** | Platform-Engineers | cluster-admin | 8 hours |
| **Namespace Admin** | Namespace-Admins | namespace-admin | 8 hours |
| **Developer** | Developers | developer | 12 hours |
| **Auditor** | Auditors | view | 12 hours |

## Architecture

### User Personas and Permissions

#### 1. Administrators

- **AWS Access**: Full administrative access (`AdministratorAccess` managed policy)
- **K8s Access**: `cluster-admin` (system:masters group)
- **Session**: 4 hours (shorter for high privilege)
- **Account Access**: All accounts including management
- **Use Case**: Platform owners, break-glass scenarios

#### 2. Platform Engineers

- **AWS Access**: EKS cluster management, VPC/networking, ECR, no IAM Identity management
- **K8s Access**: `cluster-admin` (system:masters group)
- **Session**: 8 hours (workday coverage)
- **Account Access**: All environment accounts (not management)
- **Use Case**: Building and managing Kubernetes clusters

#### 3. Namespace Administrators

- **AWS Access**: EKS describe, ECR push/pull, CloudWatch logs, Secrets Manager read
- **K8s Access**: `namespace-admin` (custom ClusterRole with full namespace control)
- **Session**: 8 hours (workday coverage)
- **Account Access**: Non-production only (dev, staging, sandbox)
- **Use Case**: Team leads managing their team's Kubernetes namespace

#### 4. Developers

- **AWS Access**: EKS describe, ECR push/pull, CloudWatch logs
- **K8s Access**: `developer` (custom ClusterRole - deploy pods, limited secrets)
- **Session**: 12 hours (convenience for development)
- **Account Access**: Non-production only (dev, staging, sandbox)
- **Use Case**: Day-to-day application deployment

#### 5. Auditors

- **AWS Access**: Read-only + Cost Explorer + Security Hub
- **K8s Access**: `view` (built-in ClusterRole - read-only)
- **Session**: 12 hours (long read-only sessions)
- **Account Access**: All accounts for compliance
- **Use Case**: Compliance auditing and monitoring

### Environment Access Matrix

| Persona | Management | Sandbox | Dev | Staging | Production |
|---------|:----------:|:-------:|:---:|:-------:|:----------:|
| Administrator | ✅ | ✅ | ✅ | ✅ | ✅ |
| Platform Engineer | ❌ | ✅ | ✅ | ✅ | ✅ |
| Namespace Admin | ❌ | ✅ | ✅ | ✅ | ❌ |
| Developer | ❌ | ✅ | ✅ | ✅ | ❌ |
| Auditor | ❌ | ✅ | ✅ | ✅ | ✅ |

## Prerequisites

1. **AWS Organizations** must be enabled in your management account
2. **IAM Identity Center** must be enabled
3. You must run this Terraform in the **management account** where IAM Identity Center is configured
4. Appropriate AWS credentials with permissions to manage IAM Identity Center resources

## Usage

### 1. Configure Backend

Edit `backend.tf` to configure your Terraform backend (Terraform Cloud or S3).

### 2. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
owner       = "Platform-Team"
environment = "Management"
managed_by  = "Terraform"
layer       = "Foundation"

# All accounts - Administrators, Platform Engineers, and Auditors get access
additional_account_ids = [
  "111111111111",  # Dev account
  "222222222222",  # Staging account
  "333333333333",  # Production account
  "444444444444",  # Sandbox account
]

# Non-production only - Namespace Admins and Developers get access
non_production_account_ids = [
  "111111111111",  # Dev account
  "222222222222",  # Staging account
  "444444444444",  # Sandbox account
]
```

### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## EKS RBAC Integration

After creating the SSO groups, you need to configure EKS clusters to map SSO roles to Kubernetes RBAC. Add this to your EKS cluster's `aws-auth` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    # Administrators - cluster-admin
    - rolearn: arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*
      username: admin:{{SessionName}}
      groups:
        - system:masters

    # Platform Engineers - cluster-admin
    - rolearn: arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_PlatformEngineerAccess_*
      username: platform:{{SessionName}}
      groups:
        - system:masters

    # Namespace Admins - namespace-admin (custom ClusterRole)
    - rolearn: arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_NamespaceAdminAccess_*
      username: ns-admin:{{SessionName}}
      groups:
        - namespace-admins

    # Developers - developer (custom ClusterRole)
    - rolearn: arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DeveloperAccess_*
      username: dev:{{SessionName}}
      groups:
        - developers

    # Auditors - view (built-in ClusterRole)
    - rolearn: arn:aws:iam::ACCOUNT:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AuditorAccess_*
      username: auditor:{{SessionName}}
      groups:
        - auditors
```

### Custom Kubernetes RBAC Resources

Deploy these custom ClusterRoles for namespace-admin and developer personas:

```yaml
# Namespace Admin ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-admin
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
---
# Developer ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "replicasets", "statefulsets", "jobs", "cronjobs", "services", "configmaps", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log", "pods/exec"]
    verbs: ["get", "create"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]  # Read-only secrets
```

## Adding Test Users

For learning purposes, create test users in IAM Identity Center and add them to groups:

| Username | Email | Groups |
|----------|-------|--------|
| admin-user | `admin@example.com` | Administrators |
| platform-user | `platform@example.com` | Platform-Engineers |
| ns-admin-user | `ns-admin@example.com` | Namespace-Admins |
| dev-user | `developer@example.com` | Developers |
| audit-user | `auditor@example.com` | Auditors |

### Adding Users via AWS CLI

```bash
# Get the Identity Store ID
IDENTITY_STORE_ID=$(terraform output -raw identity_store_id)

# Add a user to Developers group
aws identitystore create-group-membership \
  --identity-store-id $IDENTITY_STORE_ID \
  --group-id $(terraform output -raw developers_group_id) \
  --member-id UserId=<user-id>
```

## Outputs

```bash
# SSO Instance
terraform output sso_instance_arn
terraform output identity_store_id

# Group IDs (for adding users)
terraform output admin_group_id
terraform output platform_engineers_group_id
terraform output namespace_admins_group_id
terraform output developers_group_id
terraform output auditors_group_id

# Permission Set ARNs (for EKS aws-auth mapping)
terraform output admin_permission_set_arn
terraform output platform_engineers_permission_set_arn
terraform output namespace_admins_permission_set_arn
terraform output developers_permission_set_arn
terraform output auditors_permission_set_arn

# Summary of all personas
terraform output user_personas_summary
```

## Security Considerations

1. **Least Privilege**: Each persona has minimum permissions needed for their role
2. **Session Duration**: Higher privilege = shorter sessions (4hr admin vs 12hr developer)
3. **Production Access**: Only Administrators, Platform Engineers, and Auditors can access production
4. **Resource Restrictions**: Many permissions are scoped to `eks-*` named resources
5. **PassRole Protection**: IAM PassRole is restricted to EKS services only
6. **MFA Recommendation**: Enable MFA for all users, especially administrators

## Testing Access Levels

After setup, test each persona by:

1. **Administrator Test**: Create IAM role, deploy EKS cluster, access any K8s resource
2. **Platform Engineer Test**: Deploy EKS cluster, cannot modify IAM, full K8s access
3. **Namespace Admin Test**: Full control within assigned namespace, no cluster resources
4. **Developer Test**: Deploy pods, cannot access secrets directly, can view logs
5. **Auditor Test**: Read-only access to all resources, cannot modify anything

## References

- [ADR-015: User Personas for AWS SSO and EKS RBAC](../../../../docs/reference/architecture-decision-register/ADR-015-user-personas-aws-sso-eks.md)
- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [EKS User Guide - IAM Identity Mapping](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
