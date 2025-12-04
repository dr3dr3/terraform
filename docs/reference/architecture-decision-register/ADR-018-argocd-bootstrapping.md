# ADR-018: ArgoCD Bootstrapping Strategy for EKS Clusters

| Metadata       | Value                                              |
|----------------|---------------------------------------------------|
| **Status**     | Approved                                          |
| **Date**       | 2024-12-04                                        |
| **Decision**   | Terraform Helm Bootstrap with App of Apps Pattern |
| **Deciders**   | Platform Engineering Team                         |
| **Categories** | Infrastructure, GitOps, Kubernetes                |

---

## Context

We are adopting Infrastructure as Code (IaC) and GitOps practices for managing our AWS EKS Kubernetes clusters and the workloads running on them.

Our technology stack includes:

- **Infrastructure provisioning:** Terraform Cloud
- **Container orchestration:** AWS EKS
- **Source control:** GitHub
- **CI/CD:** To be managed via GitOps and if necessary using GitHub actions

We have established Terraform as the tool for provisioning and managing AWS infrastructure, including EKS clusters. We have selected ArgoCD as our GitOps operator for managing Kubernetes workloads declaratively from Git repositories.

### The Bootstrap Problem

A fundamental challenge exists when adopting GitOps: ArgoCD cannot deploy itself. Before ArgoCD can manage applications declaratively from Git, something must first install and configure ArgoCD on the cluster. This creates a "chicken and egg" problem that requires a deliberate architectural decision.

### Requirements

1. **Declarative configuration:** All configuration should be stored in Git
2. **Minimal imperative steps:** Reduce manual or scripted interventions
3. **Clear ownership boundaries:** Define what Terraform manages vs. what ArgoCD manages
4. **Self-healing capability:** The system should converge to desired state automatically
5. **Auditability:** All changes should be traceable through Git history
6. **Team autonomy:** Enable teams to manage their own applications within guardrails

---

## Decision

**We will use Terraform to bootstrap ArgoCD via Helm, combined with an initial App of Apps pattern that enables ArgoCD to become self-managing.**

This approach establishes a clear boundary:

- **Terraform manages:** AWS infrastructure, EKS cluster, IAM roles, and the initial ArgoCD installation with a bootstrap Application resource
- **ArgoCD manages:** Itself (self-managed), all cluster addons, and all workloads

---

## Options Considered

### Option 1: Terraform Helm Provider Only

Use Terraform to deploy ArgoCD via the Helm provider as part of EKS provisioning, with ongoing ArgoCD configuration managed through Terraform.

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.0"
  
  values = [file("${path.module}/argocd-values.yaml")]
}
```

**Advantages:**

- Single pipeline and toolchain
- Familiar to teams already using Terraform
- ArgoCD is ready immediately when cluster provisioning completes

**Disadvantages:**

- Blurs the boundary between infrastructure and application concerns
- Terraform state contains in-cluster resources, increasing state complexity
- Ongoing ArgoCD configuration changes require Terraform runs
- Does not leverage GitOps for ArgoCD's own configuration

### Option 2: Terraform Bootstrap with App of Apps Pattern (Selected)

Use Terraform to install ArgoCD and create a single bootstrap Application resource. This Application points to a Git repository containing an "App of Apps" that defines ArgoCD's own configuration and all other applications.

**Advantages:**

- Clear handoff point from Terraform to GitOps
- ArgoCD becomes self-managing immediately after bootstrap
- Minimal Terraform footprint for in-cluster resources
- Full GitOps benefits for all cluster configuration
- Teams can manage applications through Git without Terraform access

**Disadvantages:**

- Requires understanding of the App of Apps pattern
- Initial setup is slightly more complex
- Two repositories to coordinate (infrastructure and GitOps)

### Option 3: Separate Bootstrap Script/Pipeline

Terraform provisions only AWS infrastructure and EKS. A separate CI/CD pipeline or shell script installs ArgoCD and applies the bootstrap configuration.

**Advantages:**

- Pure separation of concerns—Terraform does only infrastructure
- Flexibility in bootstrap tooling choices

**Disadvantages:**

- Two pipelines to coordinate and maintain
- Potential race conditions between cluster readiness and ArgoCD installation
- Additional CI/CD complexity
- Harder to ensure idempotent bootstrapping

### Option 4: AWS EKS Blueprints Addons

Leverage the AWS EKS Blueprints Terraform module, which includes built-in support for ArgoCD and the App of Apps pattern.

**Advantages:**

- Battle-tested patterns from AWS
- Handles many edge cases and integrations
- Active community and documentation

**Disadvantages:**

- Highly opinionated—may conflict with existing conventions
- Adds abstraction layer that obscures underlying configuration
- Dependency on external module maintenance
- May include unnecessary components

---

## The App of Apps Pattern Explained

The App of Apps pattern is a hierarchical approach to organizing ArgoCD Applications. Instead of creating each Application individually, you create a single "root" Application that references other Applications defined in a Git repository.

### Conceptual Structure

```text
Bootstrap Application (created by Terraform)
    │
    └── points to Git repo containing:
            │
            ├── ArgoCD Self-Management Application
            │       └── ArgoCD Helm values, RBAC, projects
            │
            ├── Cluster Addons Application
            │       ├── ingress-nginx
            │       ├── cert-manager
            │       ├── external-dns
            │       ├── external-secrets
            │       └── kube-prometheus-stack
            │
            └── Workloads Application
                    ├── team-alpha/
                    ├── team-bravo/
                    └── team-charlie/
```

### How It Works

1. **Terraform creates the bootstrap Application:**

   ```hcl
   resource "kubectl_manifest" "argocd_bootstrap" {
     depends_on = [helm_release.argocd]
     yaml_body  = <<-YAML
       apiVersion: argoproj.io/v1alpha1
       kind: Application
       metadata:
         name: bootstrap
         namespace: argocd
       spec:
         project: default
         source:
           repoURL: https://github.com/org/gitops-config.git
           targetRevision: main
           path: bootstrap
         destination:
           server: https://kubernetes.default.svc
           namespace: argocd
         syncPolicy:
           automated:
             prune: true
             selfHeal: true
     YAML
   }
   ```

2. **The bootstrap path contains Application manifests:**

   ```yaml
   # bootstrap/argocd-self.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: argocd
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/org/gitops-config.git
       targetRevision: main
       path: argocd
       helm:
         valueFiles:
           - values.yaml
     destination:
       server: https://kubernetes.default.svc
       namespace: argocd
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

3. **ArgoCD syncs and becomes self-managing:**
   - ArgoCD detects the bootstrap Application
   - It creates the child Applications defined in the bootstrap path
   - One of those Applications points back to ArgoCD's own configuration
   - ArgoCD now manages its own upgrades and configuration changes

### Repository Structure

```text
gitops-config/
├── bootstrap/
│   ├── argocd-self.yaml          # ArgoCD manages itself
│   ├── cluster-addons.yaml       # Parent app for infrastructure addons
│   └── workloads.yaml            # Parent app for team workloads
│
├── argocd/
│   ├── Chart.yaml
│   ├── values.yaml               # ArgoCD Helm values
│   └── templates/
│       ├── projects.yaml         # ArgoCD Projects for multi-tenancy
│       └── rbac.yaml             # ArgoCD RBAC configuration
│
├── cluster-addons/
│   ├── ingress-nginx/
│   ├── cert-manager/
│   ├── external-dns/
│   ├── external-secrets/
│   └── kube-prometheus-stack/
│
└── workloads/
    ├── team-alpha/
    │   ├── service-a.yaml
    │   └── service-b.yaml
    ├── team-bravo/
    └── team-charlie/
```

### Benefits of App of Apps

1. **Single source of truth:** All application definitions live in Git
2. **Hierarchical organization:** Logical grouping of related applications
3. **Scalability:** Add new applications by adding YAML files—no Terraform changes needed
4. **Self-healing:** ArgoCD continuously reconciles actual state with desired state
5. **Multi-tenancy:** Use ArgoCD Projects to isolate teams and enforce policies
6. **Audit trail:** All changes flow through Git pull requests

### ApplicationSets as an Evolution

For dynamic application generation, consider ArgoCD ApplicationSets. They can automatically generate Applications based on Git directory structure, cluster labels, or external data sources.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: team-workloads
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/org/gitops-config.git
        revision: main
        directories:
          - path: workloads/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/gitops-config.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
```

---

## Implementation Architecture

### Component Responsibilities

| Component | Managed By | Contents |
|-----------|-----------|----------|
| VPC, Subnets, Security Groups | Terraform | AWS networking infrastructure |
| EKS Cluster, Node Groups | Terraform | Kubernetes control plane and compute |
| IAM Roles (IRSA) | Terraform | Service account role mappings |
| ArgoCD Installation (initial) | Terraform (Helm) | Base ArgoCD deployment |
| Bootstrap Application | Terraform (kubectl) | Single Application pointing to Git |
| ArgoCD Configuration | ArgoCD | Self-managed via App of Apps |
| Cluster Addons | ArgoCD | Ingress, certs, monitoring, etc. |
| Workloads | ArgoCD | All application deployments |

### Sync Flow

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         TERRAFORM DOMAIN                            │
├─────────────────────────────────────────────────────────────────────┤
│  AWS Infrastructure    EKS Cluster    ArgoCD Helm    Bootstrap App  │
│        ▼                   ▼              ▼               ▼         │
│    [VPC/IAM]    ──►    [EKS]    ──►   [ArgoCD]   ──►  [App YAML]   │
└─────────────────────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          ARGOCD DOMAIN                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    Bootstrap App ──► Git Repo ──► Child Applications                │
│         │                              │                            │
│         ▼                              ▼                            │
│    [argocd-self]              [cluster-addons]  [workloads]         │
│         │                         │                  │              │
│         ▼                         ▼                  ▼              │
│    ArgoCD Config          ingress-nginx      team-alpha-svc-a       │
│    Projects/RBAC          cert-manager       team-bravo-svc-x       │
│                           external-dns       team-charlie-svc-y     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Consequences

### Positive

- **Clear ownership boundary:** Terraform manages infrastructure; ArgoCD manages everything in-cluster after bootstrap
- **GitOps for cluster configuration:** All changes to ArgoCD, addons, and workloads go through Git
- **Self-healing:** ArgoCD automatically corrects drift from desired state
- **Scalable onboarding:** New applications require only a Git commit, not Terraform access
- **Reduced Terraform state complexity:** Minimal Kubernetes resources in Terraform state
- **Audit trail:** Complete history of all cluster configuration changes in Git

### Negative

- **Learning curve:** Teams must understand the App of Apps pattern
- **Two-repo coordination:** Infrastructure and GitOps repos must be kept in sync during initial setup
- **Bootstrap dependency:** If the bootstrap Application is accidentally deleted, manual intervention is required
- **Eventual consistency:** Changes propagate through Git sync cycles, not immediately

### Mitigations

| Risk | Mitigation |
|------|------------|
| Bootstrap Application deletion | Protect with ArgoCD finalizers and RBAC; document recovery procedure |
| Git repository unavailability | Use repository mirroring; ArgoCD caches last-known state |
| Configuration drift during bootstrap | Use `syncPolicy.automated` with `selfHeal: true` |
| Team confusion about boundaries | Document clearly; provide golden path templates |

---

## Implementation: Adding ArgoCD to EKS Auto Mode

The existing EKS Auto Mode Terraform configuration at `terraform/env-development/platform-layer/eks-auto-mode/` needs the following additions to bootstrap ArgoCD.

### Required Provider Additions

Add the Helm and Kubernetes providers to `main.tf`:

```hcl
terraform {
  required_providers {
    # ... existing providers ...
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
    }
  }
}

# Kubectl provider configuration
provider "kubectl" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}
```

### New File: `argocd.tf`

Create a new file `argocd.tf` in the `eks-auto-mode/` directory:

```hcl
# =============================================================================
# ArgoCD Bootstrap Configuration
# =============================================================================
# Installs ArgoCD via Helm and creates the bootstrap Application
# that enables ArgoCD to become self-managing via App of Apps pattern
# =============================================================================

# -----------------------------------------------------------------------------
# ArgoCD Namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_cluster.main]
}

# -----------------------------------------------------------------------------
# ArgoCD Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name

  # Wait for all resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    templatefile("${path.module}/argocd-values.yaml", {
      cluster_name = local.cluster_name
      environment  = var.environment
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    kubernetes_namespace.argocd
  ]
}

# -----------------------------------------------------------------------------
# Bootstrap Application (App of Apps)
# -----------------------------------------------------------------------------

resource "kubectl_manifest" "argocd_bootstrap" {
  count = var.enable_argocd && var.argocd_bootstrap_repo_url != "" ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: bootstrap
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${var.argocd_bootstrap_repo_url}
        targetRevision: ${var.argocd_bootstrap_repo_revision}
        path: ${var.argocd_bootstrap_repo_path}
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}
```

### New File: `argocd-values.yaml`

Create `argocd-values.yaml` in the `eks-auto-mode/` directory:

```yaml
# ArgoCD Helm Values for EKS Auto Mode
# See: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd

global:
  # Add cluster-specific labels
  additionalLabels:
    cluster: ${cluster_name}
    environment: ${environment}

# Server configuration
server:
  # Enable insecure mode if using ingress with TLS termination
  extraArgs:
    - --insecure

  # Resource requests/limits for Auto Mode
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Service configuration
  service:
    type: ClusterIP

# Repo server configuration
repoServer:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Application controller configuration
controller:
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# Redis configuration
redis:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

# Notifications controller (optional)
notifications:
  enabled: false

# ApplicationSet controller
applicationSet:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

# Dex (SSO) - disable if using external SSO
dex:
  enabled: false

# High Availability - enable for production
# ha:
#   enabled: true
```

### Variable Additions for `variables.tf`

Add these variables to `variables.tf`:

```hcl
# -----------------------------------------------------------------------------
# ArgoCD Configuration
# -----------------------------------------------------------------------------

variable "enable_argocd" {
  description = "Enable ArgoCD installation for GitOps"
  type        = bool
  default     = false
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "7.7.5"  # Check for latest: https://github.com/argoproj/argo-helm/releases
}

variable "argocd_bootstrap_repo_url" {
  description = "Git repository URL for the ArgoCD bootstrap App of Apps"
  type        = string
  default     = ""
}

variable "argocd_bootstrap_repo_revision" {
  description = "Git revision (branch/tag) for the bootstrap repository"
  type        = string
  default     = "main"
}

variable "argocd_bootstrap_repo_path" {
  description = "Path within the repository containing the bootstrap Application manifests"
  type        = string
  default     = "bootstrap"
}
```

### Output Additions for `outputs.tf`

Add these outputs to `outputs.tf`:

```hcl
# -----------------------------------------------------------------------------
# ArgoCD Information
# -----------------------------------------------------------------------------

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.enable_argocd ? kubernetes_namespace.argocd[0].metadata[0].name : null
}

output "argocd_server_service" {
  description = "ArgoCD server service name for port-forwarding"
  value       = var.enable_argocd ? "argocd-server" : null
}

output "argocd_initial_admin_secret" {
  description = "Command to get ArgoCD initial admin password"
  value       = var.enable_argocd ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d" : null
}

output "argocd_port_forward_command" {
  description = "Command to port-forward ArgoCD server for local access"
  value       = var.enable_argocd ? "kubectl port-forward svc/argocd-server -n argocd 8080:443" : null
}
```

### Example `terraform.tfvars` Update

Add to `terraform.tfvars`:

```hcl
# ArgoCD Configuration
enable_argocd                  = true
argocd_chart_version           = "7.7.5"
argocd_bootstrap_repo_url      = "https://github.com/dr3dr3/gitops-config.git"
argocd_bootstrap_repo_revision = "main"
argocd_bootstrap_repo_path     = "bootstrap"
```

### Deployment Order

1. First, apply the EKS cluster without ArgoCD (`enable_argocd = false`)
2. Verify the cluster is healthy and accessible
3. Enable ArgoCD (`enable_argocd = true`) and apply again
4. Access ArgoCD UI via port-forward to verify installation
5. Create the GitOps config repository with bootstrap Applications
6. Set `argocd_bootstrap_repo_url` and apply to enable App of Apps

---

## Related Decisions

- ADR: EKS Cluster Architecture (prerequisite)
- ADR: Terraform State Management Strategy (prerequisite)
- ADR: Git Repository Structure for GitOps (to be created)
- ADR: ArgoCD Multi-Tenancy and RBAC Model (to be created)

---

## References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ArgoCD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [AWS EKS Blueprints](https://aws-ia.github.io/terraform-aws-eks-blueprints/)
