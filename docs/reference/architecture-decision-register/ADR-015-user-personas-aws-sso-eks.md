# Architecture Decision Record: User Personas for AWS SSO and EKS RBAC

## Status

Approved

## Context

We are setting up a learning environment that mimics production access patterns. This requires defining user personas that can be assigned through AWS IAM Identity Center (SSO) and mapped to corresponding Kubernetes RBAC roles in EKS clusters.

### Current Situation

- AWS IAM Identity Center is configured in the Management account
- Currently have 3 groups: Administrators, Platform-Engineers, ReadOnly
- Need to support EKS cluster access patterns
- Must follow the principle of least privilege
- Environment separation across Dev, Staging, Production accounts

### Goals

1. Create realistic user personas for learning/testing AWS SSO + EKS integration
2. Enable testing of different access levels to understand least privilege
3. Map AWS SSO permission sets to Kubernetes RBAC roles
4. Support the typical roles found in production organizations

## Decision

Implement a 6-tier user persona model that maps AWS SSO permission sets to Kubernetes RBAC roles.

### User Personas

| Persona | AWS SSO Group | Permission Set | K8s RBAC Role | Description |
|---------|---------------|----------------|---------------|-------------|
| **Cloud Administrator** | Administrators | AdministratorAccess | cluster-admin | Full AWS + K8s access |
| **Platform Engineer** | Platform-Engineers | PlatformEngineerAccess | cluster-admin | EKS/infra management |
| **Namespace Administrator** | Namespace-Admins | NamespaceAdminAccess | namespace-admin | Full namespace control |
| **Developer** | Developers | DeveloperAccess | developer | Deploy apps, limited secrets |
| **Auditor** | Auditors | AuditorAccess | view | Read-only for compliance |
| **Service Account** | (N/A - programmatic) | (Via OIDC/IRSA) | service-account | Workload identity |

### Permission Matrix

#### AWS Permissions by Persona

| Capability | Administrator | Platform Engineer | Namespace Admin | Developer | Auditor |
|------------|:-------------:|:-----------------:|:---------------:|:---------:|:-------:|
| IAM Management | ✅ | ❌ | ❌ | ❌ | ❌ |
| EKS Cluster Create/Delete | ✅ | ✅ | ❌ | ❌ | ❌ |
| EKS Cluster Describe | ✅ | ✅ | ✅ | ✅ | ✅ |
| VPC/Networking | ✅ | ✅ | ❌ | ❌ | ❌ |
| S3 Full Access | ✅ | ❌ | ❌ | ❌ | ❌ |
| S3 Read Access | ✅ | ✅ | ✅ | ✅ | ✅ |
| ECR Push/Pull | ✅ | ✅ | ✅ | ✅ | ❌ |
| CloudWatch Logs | ✅ | ✅ | ✅ | ✅ | ✅ |
| Secrets Manager Read | ✅ | ✅ | ✅ | ✅ | ❌ |
| Cost Explorer | ✅ | ❌ | ❌ | ❌ | ✅ |

#### Kubernetes Permissions by Persona

| Capability | cluster-admin | namespace-admin | developer | view |
|------------|:-------------:|:---------------:|:---------:|:----:|
| Cluster-wide resources | ✅ | ❌ | ❌ | ❌ |
| Create namespaces | ✅ | ❌ | ❌ | ❌ |
| RBAC management | ✅ | ❌ | ❌ | ❌ |
| Deployments/StatefulSets | ✅ | ✅ | ✅ | 👁️ |
| Services/Ingresses | ✅ | ✅ | ✅ | 👁️ |
| ConfigMaps | ✅ | ✅ | ✅ | 👁️ |
| Secrets | ✅ | ✅ | ❌ | ❌ |
| PersistentVolumeClaims | ✅ | ✅ | ✅ | 👁️ |
| Pod exec/logs | ✅ | ✅ | ✅ | ❌ |
| Pod delete | ✅ | ✅ | ✅ | ❌ |
| View all resources | ✅ | ✅ (ns only) | ✅ (ns only) | ✅ |

Legend: ✅ = Full access, ❌ = No access, 👁️ = Read-only

### Session Duration Strategy

| Permission Set | Session Duration | Rationale |
|----------------|------------------|-----------|
| AdministratorAccess | 4 hours | High privilege = shorter sessions |
| PlatformEngineerAccess | 8 hours | Workday coverage for cluster ops |
| NamespaceAdminAccess | 8 hours | Workday coverage |
| DeveloperAccess | 12 hours | Convenience for development work |
| AuditorAccess | 12 hours | Long read-only sessions for audits |

### Environment Access Strategy

| Persona | Management | Sandbox | Development | Staging | Production |
|---------|:----------:|:-------:|:-----------:|:-------:|:----------:|
| Administrator | ✅ | ✅ | ✅ | ✅ | ✅ |
| Platform Engineer | ❌ | ✅ | ✅ | ✅ | ✅ |
| Namespace Admin | ❌ | ✅ | ✅ | ✅ | ❌ |
| Developer | ❌ | ✅ | ✅ | ✅ | ❌ |
| Auditor | ❌ | ✅ | ✅ | ✅ | ✅ |

## Implementation

### AWS SSO Configuration (Terraform)

The `iam-roles-for-people` Terraform stack will create:

1. **Identity Store Groups**: One per persona
2. **Permission Sets**: One per persona with inline/managed policies
3. **Account Assignments**: Groups assigned to appropriate accounts

### EKS RBAC Configuration (Kubernetes)

The `aws-auth` ConfigMap in each EKS cluster maps SSO roles to K8s groups:

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
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Rationale

### Why These Specific Personas?

1. **Administrator**: Required for initial setup and break-glass scenarios
2. **Platform Engineer**: Separation of duties - infra management without IAM control
3. **Namespace Admin**: Team leads who manage their team's K8s namespace
4. **Developer**: Day-to-day application deployment without cluster-wide access
5. **Auditor**: Compliance requirement for read-only oversight

### Alignment with Principle of Least Privilege

- Each persona has the minimum permissions needed for their role
- Production access restricted to essential personnel
- Secrets access tiered based on need
- Session durations inversely proportional to privilege level

### Learning Value

By having multiple personas, you can:

1. Log in as different users to experience their access limitations
2. Test RBAC boundary enforcement
3. Understand how AWS SSO integrates with EKS
4. Practice troubleshooting access issues
5. Validate compliance controls

## Consequences

### Positive

- Clear separation of duties
- Realistic production access patterns for learning
- Easy to test different access levels
- Foundation for compliance requirements
- Scalable pattern for adding more personas

### Negative

- More groups and permission sets to manage
- Complex aws-auth ConfigMap
- Requires Kubernetes RBAC configuration alongside AWS SSO
- Additional testing required when modifying permissions

### Neutral

- Requires documentation for users on which persona to use
- Need to create test users in each group for testing

## Testing Strategy

### Test Users to Create

For learning purposes, create these test users in IAM Identity Center:

| Username | Email | Groups |
|----------|-------|--------|
| admin-user | `admin@example.com` | Administrators |
| platform-user | `platform@example.com` | Platform-Engineers |
| ns-admin-user | `ns-admin@example.com` | Namespace-Admins |
| dev-user | `developer@example.com` | Developers |
| audit-user | `auditor@example.com` | Auditors |

### Test Scenarios

1. **Administrator Test**: Create IAM role, deploy EKS cluster, access any K8s resource
2. **Platform Engineer Test**: Deploy EKS cluster, cannot modify IAM, full K8s access
3. **Namespace Admin Test**: Full control within assigned namespace, no cluster resources
4. **Developer Test**: Deploy pods, cannot access secrets directly, can view logs
5. **Auditor Test**: Read-only access to all resources, cannot modify anything

## Related Decisions

- [ADR-010: AWS IAM Role Structure](./ADR-010-aws-iam-role-structure.md) - OIDC roles for Terraform
- [ADR-011: Sandbox Environment](./ADR-011-sandbox-environment.md) - Testing environment

## References

- [AWS IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/)
- [EKS User Guide - IAM Identity Mapping](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Cloud Posse terraform-aws-sso](https://github.com/cloudposse/terraform-aws-sso)

---

## Document Information

- **Created**: November 29, 2025
- **Author**: Platform Engineering Team
- **Reviewers**: [To be assigned]
- **Status**: Approved
- **Version**: 1.0
