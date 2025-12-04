# ADR-019: ArgoCD Implementation Options - EKS Capability vs Self-Managed

| Metadata       | Value                                              |
|----------------|---------------------------------------------------|
| **Status**     | Approved                                          |
| **Date**       | 2025-12-04                                        |
| **Supersedes** | Updates ADR-018 with additional implementation option |
| **Deciders**   | Platform Engineering Team                         |
| **Categories** | Infrastructure, GitOps, Kubernetes, AWS           |

---

## Context

In ADR-018, we decided to bootstrap ArgoCD via Terraform Helm with an App of Apps pattern. Since that decision, AWS has released **EKS Capabilities**, a new fully managed feature that includes ArgoCD as a first-class offering.

EKS Capabilities is a layered set of fully managed cluster features that run within EKS rather than in your clusters, eliminating the need to install, maintain, and scale critical platform components on your worker nodes. This ADR evaluates whether the new EKS Capability for ArgoCD should replace or complement our self-managed approach.

### What Are EKS Capabilities?

EKS Capabilities are Kubernetes-native features for:

- **Argo CD**: GitOps-based continuous deployment
- **ACK (AWS Controllers for Kubernetes)**: AWS resource management via Kubernetes APIs
- **kro (Kube Resource Orchestrator)**: Custom Kubernetes API abstractions

Key characteristics:

- Runs **in EKS** (AWS-managed infrastructure), not on your worker nodes
- Fully managed by AWS (security patching, updates, operational management)
- Kubernetes-native APIs and tools (`kubectl` works the same way)
- Designed for GitOps workflows with declarative, version-controlled configuration

---

## Decision

**We will adopt a hybrid approach: Use EKS Capability for ArgoCD as the primary implementation for new clusters, while maintaining the option for self-managed ArgoCD when specific unsupported features are required.**

This decision recognizes that:

1. EKS Capability for ArgoCD significantly reduces operational overhead
2. Some advanced features (CMPs, custom Lua scripts, Notifications) are not available in the managed offering
3. Our current requirements can be met by the managed capability
4. Migration from self-managed to managed is supported and documented by AWS

---

## Options Considered

### Option 1: Self-Managed ArgoCD via Terraform Helm (ADR-018 Approach)

Use Terraform to deploy ArgoCD via Helm provider with the App of Apps pattern for self-management.

**Advantages:**

- Full control over ArgoCD configuration
- All upstream ArgoCD features available (CMPs, custom Lua scripts, Notifications, Image Updater)
- Custom SSO providers supported
- Direct access to `argocd-cm`, `argocd-params` ConfigMaps
- No per-Application pricing
- UI extensions and custom banners supported

**Disadvantages:**

- Requires managing ArgoCD installation, upgrades, and security patches
- ArgoCD components consume cluster resources (CPU, memory)
- Team must maintain expertise in ArgoCD operations
- Complex multi-cluster setup with IRSA and VPC networking
- Manual intervention required for ArgoCD upgrades

**Cost Model:**

- No direct ArgoCD costs
- Cluster resource consumption for ArgoCD components (~1-2 vCPU, 2-4GB memory)
- Operational overhead for maintenance

### Option 2: EKS Capability for ArgoCD (AWS Managed)

Use the new EKS Capability to deploy ArgoCD as a fully managed service.

**Advantages:**

- **Zero operational overhead**: AWS handles installation, upgrades, patching
- **Runs outside cluster**: No worker node resource consumption
- **Simplified multi-cluster**: EKS Access Entries eliminate IRSA complexity
- **Private cluster access**: Automatic connectivity to fully private EKS clusters
- **AWS service integration**: Direct CodeCommit, ECR, CodeConnections, Secrets Manager integration
- **AWS Identity Center**: Native SSO integration with existing identity infrastructure
- **Hosted UI**: Dedicated Argo CD UI endpoint managed by AWS
- **Cross-account deployments**: Simplified via EKS Access Entries (no IAM role chaining)

**Disadvantages:**

- **Feature limitations**:
  - No Config Management Plugins (CMPs) for custom manifest generation
  - No custom Lua scripts for resource health assessment
  - No Notifications controller
  - No Argo CD Image Updater
  - Only AWS Identity Center for SSO (no custom providers)
  - No UI extensions or custom banners
  - No direct ConfigMap access (`argocd-cm`, `argocd-params`)
- **Single namespace initially**: Deploy to one namespace per capability (multi-namespace coming)
- **EKS-only targets**: Only Amazon EKS clusters as deployment targets (by ARN, not API URL)
- **Per-Application pricing**: Additional costs based on Application count

**Cost Model (US East N. Virginia):**

| Component | Price |
|-----------|-------|
| Base capability hour | $0.03/hour (~$21.90/month) |
| Per Application hour | $0.0015/hour per Application |
| Example: 10 Applications | ~$21.90 + $10.95 = **$32.85/month** |
| Example: 50 Applications | ~$21.90 + $54.75 = **$76.65/month** |
| Example: 100 Applications | ~$21.90 + $109.50 = **$131.40/month** |

### Option 3: Hybrid Approach (Selected)

Start with EKS Capability for ArgoCD for new clusters. Fall back to self-managed for specific use cases requiring unsupported features.

**Advantages:**

- Reduced operational burden for majority of use cases
- Flexibility to use self-managed when needed
- Clear decision framework for when to use each approach
- Gradual migration path from self-managed to managed

**Disadvantages:**

- Two deployment patterns to document and support
- Team needs knowledge of both approaches
- Potential configuration drift between approaches

---

## Feature Comparison Matrix

| Feature | Self-Managed | EKS Capability |
|---------|--------------|----------------|
| **Core GitOps** | ✅ | ✅ |
| Applications & ApplicationSets | ✅ | ✅ |
| Automated sync with self-heal | ✅ | ✅ |
| Multi-cluster deployments | ✅ | ✅ |
| Helm, Kustomize, plain YAML | ✅ | ✅ |
| Sync waves and hooks | ✅ | ✅ |
| Rollback capabilities | ✅ | ✅ |
| Projects for multi-tenancy | ✅ | ✅ |
| Resource exclusions/inclusions | ✅ | ✅ |
| **Authentication** | | |
| AWS Identity Center SSO | Manual setup | ✅ Native |
| Custom SSO providers | ✅ | ❌ |
| Local users | ✅ | ❌ |
| **Advanced Features** | | |
| Config Management Plugins | ✅ | ❌ |
| Custom Lua health checks | ✅ | ❌ |
| Notifications controller | ✅ | ❌ |
| Image Updater | ✅ | ❌ |
| UI extensions/banners | ✅ | ❌ |
| ConfigMap access | ✅ | ❌ |
| **AWS Integration** | | |
| CodeCommit (direct) | Manual | ✅ Native |
| ECR Helm charts (direct) | Manual | ✅ Native |
| CodeConnections | Manual | ✅ Native |
| Secrets Manager | Manual | ✅ Native |
| Private cluster access | VPC peering needed | ✅ Automatic |
| Cross-account deployments | IAM role chaining | ✅ Access Entries |
| **Operations** | | |
| Runs on worker nodes | ✅ | ❌ (AWS-managed) |
| Self-managed upgrades | ✅ Required | ❌ AWS-managed |
| Security patching | Manual | ✅ AWS-managed |
| **Target Clusters** | | |
| EKS clusters | ✅ | ✅ |
| Non-EKS Kubernetes | ✅ | ❌ |
| API URL targeting | ✅ | ❌ (ARN only) |

---

## Decision Framework

### Use EKS Capability for ArgoCD when

- ✅ Deploying to EKS clusters only
- ✅ Standard GitOps workflows (Applications, ApplicationSets)
- ✅ AWS Identity Center is available for authentication
- ✅ Using AWS native Git services (CodeCommit, CodeConnections, GitHub/GitLab via CodeConnections)
- ✅ Multi-cluster deployments across accounts/regions
- ✅ Minimizing operational overhead is a priority
- ✅ Private EKS cluster access is required without VPC peering
- ✅ Cost per Application is acceptable for your scale

### Use Self-Managed ArgoCD when

- ✅ Config Management Plugins are required
- ✅ Custom Lua scripts for health checks are needed
- ✅ Notifications controller is essential
- ✅ Argo CD Image Updater integration is required
- ✅ Non-AWS SSO provider is mandated
- ✅ Deploying to non-EKS Kubernetes clusters
- ✅ UI customizations are required
- ✅ Direct ConfigMap access is needed for advanced configuration
- ✅ Cost optimization at scale (many Applications) is critical

---

## Implementation Architecture

### EKS Capability Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         TERRAFORM DOMAIN                            │
├─────────────────────────────────────────────────────────────────────┤
│  AWS Infrastructure    EKS Cluster    IAM Capability Role           │
│        ▼                   ▼              ▼                         │
│    [VPC/IAM]    ──►    [EKS]    ──►   [IAM Role]                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EKS CAPABILITY (AWS-MANAGED)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    aws eks create-capability                                        │
│         │                                                           │
│         ▼                                                           │
│    [ArgoCD Capability]  ──►  [Hosted ArgoCD UI]                    │
│         │                                                           │
│         ▼                                                           │
│    [CRDs installed in cluster]                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       GITOPS DOMAIN                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    Applications & ApplicationSets ──► Git Repos                     │
│         │                              │                            │
│         ▼                              ▼                            │
│    [cluster-addons]           [workloads]                          │
│         │                          │                                │
│         ▼                          ▼                                │
│    ingress-nginx           team-alpha-svc-a                        │
│    cert-manager            team-bravo-svc-x                        │
│    external-dns            team-charlie-svc-y                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Terraform Implementation for EKS Capability

> **Note:** Native Terraform support for EKS Capabilities was added in AWS Provider v6.25.0
> (released December 2025) via the `aws_eks_capability` resource.

```hcl
# Create IAM Capability Role
resource "aws_iam_role" "argocd_capability" {
  name = "${local.cluster_name}-argocd-capability"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:capability/${aws_eks_cluster.main.name}/*"
          }
        }
      }
    ]
  })
}

# Optional: Secrets Manager access for repository credentials
resource "aws_iam_role_policy" "argocd_secrets" {
  name = "argocd-secrets-access"
  role = aws_iam_role.argocd_capability.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:argocd/*"
      }
    ]
  })
}

# Create ArgoCD Capability using native Terraform resource (AWS Provider v6.25.0+)
resource "aws_eks_capability" "argocd" {
  cluster_name = aws_eks_cluster.main.name
  name         = "argocd"
  type         = "argocd"
  role_arn     = aws_iam_role.argocd_capability.arn

  configuration {
    argo_cd {
      namespace = "argocd"
      
      rbac_role_mapping {
        admin  = ["arn:aws:identitystore:::group/admin-group-id"]
        editor = ["arn:aws:identitystore:::group/editor-group-id"]
        viewer = ["arn:aws:identitystore:::group/viewer-group-id"]
      }
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Access the ArgoCD server URL from the capability output
output "argocd_server_url" {
  description = "The ArgoCD server URL for the managed capability"
  value       = aws_eks_capability.argocd.configuration[0].argo_cd[0].server_url
}
```

### Multi-Cluster Registration with EKS Capability

```yaml
# Register target cluster using Kubernetes Secret
apiVersion: v1
kind: Secret
metadata:
  name: development-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: development-cluster
  server: arn:aws:eks:us-west-2:111122223333:cluster/dev-cluster
  project: default
```

```bash
# Create Access Entry on target cluster for cross-cluster access
aws eks create-access-entry \
  --region us-west-2 \
  --cluster-name dev-cluster \
  --principal-arn arn:aws:iam::111122223333:role/argocd-capability-role \
  --type STANDARD \
  --kubernetes-groups argocd-managers
```

---

## Migration Path

### From Self-Managed to EKS Capability

1. **Assess feature requirements**: Review if any unsupported features are in use
2. **Scale down self-managed**: Set replica count to 0 for ArgoCD controllers
3. **Create EKS Capability**: Deploy ArgoCD capability on the cluster
4. **Export Applications**: Backup existing Application and AppProject manifests
5. **Migrate credentials**: Move repository credentials to Secrets Manager or reconfigure
6. **Update cluster references**: Change `destination.server` to use EKS cluster ARNs
7. **Apply manifests**: Deploy Applications to the managed capability
8. **Verify sync**: Confirm all applications are syncing correctly
9. **Decommission**: Remove self-managed ArgoCD installation

### CLI Differences

| Operation | Self-Managed | EKS Capability |
|-----------|--------------|----------------|
| Login | `argocd login` | Account/project tokens only |
| Add cluster | `argocd cluster add` | `argocd cluster add --aws-cluster-name <ARN>` |
| Admin commands | `argocd admin *` | Not supported |
| Auth | Password/SSO | AWS Identity Center |

---

## Cost Analysis

### Scenario: 25 Applications, Single Cluster

**Self-Managed:**

- EKS cluster: $73/month (base)
- ArgoCD resources: ~1.5 vCPU, 3GB memory ≈ $40-60/month in EC2
- Operational time: ~4-8 hours/month for maintenance
- **Total: ~$113-133/month + operational overhead**

**EKS Capability:**

- EKS cluster: $73/month (base)
- ArgoCD capability: $21.90/month (base)
- Applications: 25 × $0.0015 × 730 = $27.38/month
- **Total: ~$122.28/month (no operational overhead)**

### Scenario: 100 Applications, Multi-Cluster (3 clusters)

**Self-Managed:**

- EKS clusters: 3 × $73 = $219/month
- ArgoCD resources (hub cluster): ~$60/month
- Operational time: ~8-12 hours/month
- **Total: ~$279/month + significant operational overhead**

**EKS Capability:**

- EKS clusters: 3 × $73 = $219/month
- ArgoCD capability: $21.90/month
- Applications: 100 × $0.0015 × 730 = $109.50/month
- **Total: ~$350.40/month (no operational overhead)**

### Break-Even Analysis

The EKS Capability becomes more expensive than self-managed at approximately **150-200 Applications**, depending on:

- EC2 instance type for ArgoCD workloads
- Operational cost assumptions
- Multi-cluster complexity

---

## Consequences

### Positive

- **Reduced operational burden**: AWS manages ArgoCD lifecycle, security patching, and upgrades
- **Simplified multi-cluster**: EKS Access Entries eliminate complex IAM/IRSA configurations
- **Native AWS integration**: Direct access to CodeCommit, ECR, Secrets Manager
- **Private cluster support**: Automatic connectivity without VPC peering
- **Resource efficiency**: ArgoCD doesn't consume cluster worker node resources
- **Consistent experience**: Same APIs and CRDs as upstream ArgoCD

### Negative

- **Feature limitations**: No CMPs, custom Lua scripts, Notifications, or Image Updater
- **Vendor lock-in**: EKS-only deployment targets
- **Cost at scale**: Per-Application pricing can be expensive with many Applications
- **Single namespace (initial)**: Multi-namespace support coming in future releases
- **SSO limitation**: Only AWS Identity Center supported

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Feature gap discovered late | Maintain hybrid approach knowledge; document clear decision framework |
| Cost growth with Applications | Monitor Application count; use ApplicationSets to reduce count |
| AWS service dependency | Document fallback to self-managed; test migration procedures |
| Identity Center requirement | Plan Identity Center setup early; document federated identity options |

---

## Related Decisions

- **ADR-018**: ArgoCD Bootstrapping Strategy (superseded for new clusters)
- **ADR-010**: AWS IAM Role Structure (impacts capability role design)
- **ADR-016**: EKS Credentials Cross-Repo Access (simplified with EKS Access Entries)

---

## References

- [EKS Capabilities Overview](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html)
- [Comparing EKS Capability for Argo CD to Self-Managed](https://docs.aws.amazon.com/eks/latest/userguide/argocd-comparison.html)
- [Create an Argo CD Capability](https://docs.aws.amazon.com/eks/latest/userguide/create-argocd-capability.html)
- [Configure Repository Access](https://docs.aws.amazon.com/eks/latest/userguide/argocd-configure-repositories.html)
- [Argo CD Considerations](https://docs.aws.amazon.com/eks/latest/userguide/argocd-considerations.html)
- [Amazon EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [ArgoCD Upstream Documentation](https://argo-cd.readthedocs.io/en/stable/)
