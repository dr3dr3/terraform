# ADR-016: EKS Cluster Credentials and Cross-Repository Access Strategy

## Status

Approved

## Context

We have provisioned an AWS EKS cluster in the development environment using Terraform (`terraform/env-development/platform-layer/eks-auto-mode/`). This cluster was created and is managed by this infrastructure repository.

We need to enable access to this EKS cluster from a **separate repository** that contains a devcontainer with kubectl and other Kubernetes management tools. This follows a separation-of-concerns pattern where:

- **This repository (terraform)**: Provisions and manages cloud infrastructure (EKS cluster, VPC, IAM roles, etc.)
- **Admin repository (new)**: Contains the devcontainer environment for interacting with Kubernetes clusters

This mirrors the existing pattern used for homelab Kubernetes management (`dr3dr3/k8s-homelab-admin`), but adapted for AWS EKS with IAM-based authentication.

### Current EKS Outputs Available

The EKS Terraform configuration produces these relevant outputs:

- `cluster_name`: Name of the EKS cluster
- `cluster_endpoint`: Endpoint for the EKS cluster API server
- `cluster_certificate_authority_data`: Base64 encoded CA data (sensitive)
- `cluster_oidc_issuer_url`: OIDC issuer URL for IRSA
- `configure_kubectl`: Command to configure kubectl for this cluster

### Key Differences from Homelab Pattern

| Aspect | Homelab (Talos) | EKS (AWS) |
|--------|-----------------|-----------|
| **Authentication** | Static certificates | AWS IAM / OIDC |
| **Kubeconfig generation** | `talosctl kubeconfig` | `aws eks update-kubeconfig` |
| **Required credentials** | Cluster CA, client cert/key | AWS credentials + cluster info |
| **Credential rotation** | Manual | AWS STS (automatic short-lived tokens) |
| **Tool requirements** | talosctl, kubectl | AWS CLI, kubectl |

### Requirements

1. **Security**: Follow principle of least privilege for cluster access
2. **Portability**: Devcontainer can access multiple EKS clusters (dev, staging, prod)
3. **Automation**: Minimize manual credential copying/pasting
4. **Secret management**: Use 1Password for storing cluster connection details
5. **IAM integration**: Leverage AWS SSO/IAM Identity Center for authentication where possible
6. **Separation of concerns**: Infrastructure repo manages provisioning, admin repo manages interaction

## Decision Drivers

1. **Security posture**: Avoid storing long-lived AWS credentials
2. **Developer experience**: Simple workflow to connect to clusters
3. **Multi-cluster support**: Easy switching between environments
4. **Existing patterns**: Align with current 1Password + devcontainer approach
5. **AWS best practices**: Use IAM Roles for Service Accounts (IRSA) and short-lived credentials

## Options Considered

### Option 1: Store Full Kubeconfig in 1Password

**Description**: Generate kubeconfig with `aws eks update-kubeconfig` and store the entire file in 1Password.

**Pros**:

- Simple, mirrors homelab pattern exactly
- Single 1Password item per cluster
- Works offline once kubeconfig is retrieved

**Cons**:

- Kubeconfig includes cluster CA data (sensitive)
- Still needs AWS credentials for token refresh (tokens expire after 15 minutes by default)
- Duplicates data already available from Terraform outputs
- Doesn't leverage AWS SSO for authentication

**Not recommended** due to credential management complexity.

### Option 2: Store Cluster Connection Details + Use AWS SSO

**Description**: Store only the non-secret cluster connection details in 1Password (endpoint, name, region). Use AWS SSO/IAM Identity Center for authentication.

**Workflow**:

1. Terraform outputs cluster details → stored in 1Password
2. Admin devcontainer retrieves details from 1Password
3. User authenticates via `aws sso login`
4. Generate kubeconfig dynamically with `aws eks update-kubeconfig`

**Pros**:

- No long-lived secrets stored
- Leverages existing AWS SSO setup
- Dynamic token generation (short-lived, auto-refreshed)
- Cluster CA verified via AWS API (no manual cert management)
- Aligns with AWS security best practices

**Cons**:

- Requires AWS SSO session for each access
- Internet connectivity required
- More steps in initial setup

**Recommended approach**.

### Option 3: IAM User with EKS Access (Static Credentials)

**Description**: Create dedicated IAM user for kubectl access, store credentials in 1Password.

**Pros**:

- Works without SSO
- Simpler initial setup

**Cons**:

- Long-lived credentials are a security risk
- Violates principle of using federated identities
- Credential rotation is manual
- Not aligned with AWS best practices

**Not recommended** due to security concerns.

### Option 4: GitHub Codespaces with OIDC to AWS

**Description**: Use GitHub Codespaces for the admin environment with OIDC federation to AWS.

**Pros**:

- No local setup required
- Automatic OIDC authentication
- Cloud-based development environment

**Cons**:

- Costs associated with Codespaces
- Internet dependency
- Less control over environment
- Different workflow from local development

**Consider for future** but not primary approach.

## Decision

**Selected: Option 2** - Store Cluster Connection Details + Use AWS SSO

This approach provides the best security posture while maintaining a smooth developer experience.

## Implementation Strategy

### Phase 1: Terraform Outputs to 1Password (This Repository)

#### 1.1 Create 1Password Item Structure

Store EKS cluster connection details in 1Password with consistent naming:

```text
Vault: terraform
Item: EKS-{environment}-{cluster-name}
Category: Server

Fields:
  - cluster_name: dev-eks-auto-mode
  - cluster_endpoint: https://XXXXX.gr7.ap-southeast-2.eks.amazonaws.com
  - cluster_region: ap-southeast-2
  - aws_account_id: 123456789012
  - cluster_arn: arn:aws:eks:ap-southeast-2:123456789012:cluster/dev-eks-auto-mode
  - oidc_provider_url: https://oidc.eks.ap-southeast-2.amazonaws.com/id/XXXXX
  
Notes:
  - kubectl_command: aws eks update-kubeconfig --region ap-southeast-2 --name dev-eks-auto-mode
  - terraform_workspace: development-platform-eks-auto-mode
  - provisioned_date: 2025-12-01
```

#### 1.2 Terraform to 1Password Integration

Add a Terraform configuration to create/update 1Password items from EKS outputs:

```hcl
# 1password.tf (optional, for automation)
resource "onepassword_item" "eks_cluster" {
  vault    = data.onepassword_vault.infrastructure.uuid
  title    = "EKS-${var.environment}-${local.cluster_name}"
  category = "server"

  section {
    label = "Cluster Details"

    field {
      label = "cluster_name"
      type  = "STRING"
      value = aws_eks_cluster.main.name
    }

    field {
      label = "cluster_endpoint"
      type  = "STRING"
      value = aws_eks_cluster.main.endpoint
    }

    field {
      label = "cluster_region"
      type  = "STRING"
      value = local.region
    }

    field {
      label = "aws_account_id"
      type  = "STRING"
      value = data.aws_caller_identity.current.account_id
    }
  }
}
```

#### 1.3 Manual Approach (Alternative)

If not using 1Password Terraform provider, document the process:

```bash
# After terraform apply, export outputs and create 1Password item
cd terraform/env-development/platform-layer/eks-auto-mode

# Create 1Password item with cluster details
op item create \
  --vault "terraform" \
  --category "server" \
  --title "EKS-development-$(terraform output -raw cluster_name)" \
  "cluster_name=$(terraform output -raw cluster_name)" \
  "cluster_endpoint=$(terraform output -raw cluster_endpoint)" \
  "cluster_region=ap-southeast-2" \
  "aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

### Phase 2: Admin Repository Setup (New Repository)

#### 2.1 Repository Structure

Create a new repository `eks-admin` (or `cloud-cluster-admin` for multi-cloud):

```text
eks-admin/
├── .devcontainer/
│   ├── Dockerfile
│   └── devcontainer.json
├── clusters/
│   ├── development/
│   │   └── README.md
│   ├── staging/
│   │   └── README.md
│   └── production/
│       └── README.md
├── scripts/
│   ├── connect.sh
│   └── setup-kubeconfig.sh
├── .env.template
└── README.md
```

#### 2.2 Devcontainer Dockerfile

```dockerfile
ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="André Dreyer"

# Fish Shell
RUN apk update && apk add fish

# Install basic utilities
RUN apk add --no-cache gum yq curl wget git gcompat openssl jq

# Install 1Password CLI
RUN echo https://downloads.1password.com/linux/alpinelinux/stable/ >> /etc/apk/repositories && \
    wget https://downloads.1password.com/linux/keys/alpinelinux/support@1password.com-61ddfc31.rsa.pub -P /etc/apk/keys && \
    apk update && apk add 1password-cli

# Install AWS CLI v2
RUN apk add --no-cache aws-cli

# Install Kubectl
RUN apk add --no-cache kubectl

# Install Kubectl Krew plugin manager
RUN set -x; cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    ./"${KREW}" install krew

# Set up PATH for krew
ENV PATH="/root/.krew/bin:${PATH}"

# Install useful Krew plugins
RUN kubectl krew install ctx && \
    kubectl krew install ns && \
    kubectl krew install kor && \
    kubectl krew install neat && \
    kubectl krew install score

# Install Helm
RUN apk add --no-cache helm

# Install eksctl (optional, for EKS management)
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/eksctl /usr/local/bin

# Install k9s (terminal UI for Kubernetes)
RUN wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz && \
    tar -xzf k9s_Linux_amd64.tar.gz -C /usr/local/bin && \
    rm k9s_Linux_amd64.tar.gz

# Git configuration
RUN git config --global user.name "André Dreyer" && \
    git config --global user.email "github@andredreyer.com"

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
```

#### 2.3 Connection Script

```bash
#!/usr/bin/env fish
# scripts/connect.fish - Connect to an EKS cluster using 1Password

set -l ENVIRONMENT (test -n "$argv[1]"; and echo "$argv[1]"; or echo "development")
set -l VAULT (set -q OP_VAULT; and echo $OP_VAULT; or echo "terraform")

echo "🔐 Retrieving cluster details from 1Password..."

# Get cluster details from 1Password
set -l CLUSTER_NAME (op read "op://$VAULT/EKS-$ENVIRONMENT/cluster_name")
set -l CLUSTER_REGION (op read "op://$VAULT/EKS-$ENVIRONMENT/cluster_region")

echo "📡 Cluster: $CLUSTER_NAME"
echo "🌍 Region: $CLUSTER_REGION"

# Check AWS SSO session
echo "🔑 Checking AWS SSO session..."
if not aws sts get-caller-identity &>/dev/null
    echo "⚠️  AWS session expired. Logging in via SSO..."
    set -l PROFILE (set -q AWS_PROFILE; and echo $AWS_PROFILE; or echo "default")
    aws sso login --profile "$PROFILE"
end

# Update kubeconfig
echo "⚙️  Updating kubeconfig..."
aws eks update-kubeconfig \
    --region "$CLUSTER_REGION" \
    --name "$CLUSTER_NAME" \
    --alias "$ENVIRONMENT-$CLUSTER_NAME"

echo "✅ Connected to $CLUSTER_NAME"
echo ""
echo "Current context: "(kubectl config current-context)
echo ""
kubectl get nodes
```

#### 2.4 Environment Template

```bash
# .env.template
# 1Password Service Account Token (for automation)
OP_SERVICE_ACCOUNT_TOKEN="op://Automation/EKS-Admin-Service-Account/credential"

# AWS SSO Profile to use
AWS_PROFILE="development"

# Default 1Password vault for cluster details
OP_VAULT="terraform"
```

#### 2.5 Setup Kubeconfig Script

```bash
#!/usr/bin/env fish
# scripts/setup-kubeconfig.fish - Initial setup to configure all EKS clusters from 1Password
#
# This script differs from connect.fish in that it:
# - Discovers and configures ALL EKS clusters at once (not just one)
# - Is intended for initial devcontainer setup or when new clusters are added
# - Sets up kubectl contexts with consistent naming for easy switching
#
# Usage:
#   ./scripts/setup-kubeconfig.fish           # Set up all clusters
#   ./scripts/setup-kubeconfig.fish --list    # List available clusters without configuring

set -l VAULT (set -q OP_VAULT; and echo $OP_VAULT; or echo "terraform")
set -l LIST_ONLY false

# Parse arguments
argparse 'l/list' 'v/vault=' 'h/help' -- $argv
or exit 1

if set -q _flag_help
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list, -l       List available EKS clusters without configuring"
    echo "  --vault, -v      Specify 1Password vault (default: terraform)"
    echo "  --help, -h       Show this help message"
    exit 0
end

if set -q _flag_list
    set LIST_ONLY true
end

if set -q _flag_vault
    set VAULT $_flag_vault
end

echo "🔐 Discovering EKS clusters from 1Password vault: $VAULT"
echo ""

# Get all EKS items from 1Password (items starting with "EKS-")
# Using op item list with jq to filter and format
set -l CLUSTERS (op item list --vault "$VAULT" --format json | jq -r '.[] | select(.title | startswith("EKS-")) | .title')

if test -z "$CLUSTERS"
    echo "❌ No EKS clusters found in vault '$VAULT'"
    echo "   Ensure cluster items are named with 'EKS-' prefix (e.g., EKS-development-cluster-name)"
    exit 1
end

# Count clusters
set -l CLUSTER_COUNT (count $CLUSTERS)
echo "📋 Found $CLUSTER_COUNT EKS cluster(s):"
echo ""

# Display clusters in a table format
printf "%-40s %-20s %-20s\n" "CLUSTER ITEM" "ENVIRONMENT" "STATUS"
printf "%-40s %-20s %-20s\n" "----------------------------------------" "--------------------" "--------------------"

for CLUSTER_ITEM in $CLUSTERS
    # Extract environment from item name (e.g., "EKS-development-cluster" -> "development")
    set -l ENVIRONMENT (echo "$CLUSTER_ITEM" | sed 's/^EKS-//' | cut -d'-' -f1)
    
    if test "$LIST_ONLY" = true
        printf "%-40s %-20s %-20s\n" "$CLUSTER_ITEM" "$ENVIRONMENT" "available"
    else
        printf "%-40s %-20s %-20s\n" "$CLUSTER_ITEM" "$ENVIRONMENT" "pending"
    end
end

echo ""

# If list only, exit here
if test "$LIST_ONLY" = true
    echo "ℹ️  Run without --list to configure all clusters"
    exit 0
end

# Check AWS SSO session before proceeding
echo "🔑 Checking AWS SSO session..."
if not aws sts get-caller-identity &>/dev/null
    echo "⚠️  AWS session expired or not configured."
    echo "   Please run: aws sso login --profile <your-profile>"
    echo "   Then re-run this script."
    exit 1
end

echo "✅ AWS session valid"
echo ""

# Configure each cluster
echo "⚙️  Configuring kubeconfig for all clusters..."
echo ""

set -l SUCCESS_COUNT 0
set -l FAIL_COUNT 0

for CLUSTER_ITEM in $CLUSTERS
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 Configuring: $CLUSTER_ITEM"
    
    # Get cluster details from 1Password
    set -l CLUSTER_NAME (op read "op://$VAULT/$CLUSTER_ITEM/cluster_name" 2>/dev/null; or true)
    set -l CLUSTER_REGION (op read "op://$VAULT/$CLUSTER_ITEM/cluster_region" 2>/dev/null; or true)
    
    if test -z "$CLUSTER_NAME" -o -z "$CLUSTER_REGION"
        echo "   ❌ Failed to retrieve cluster details (cluster_name or cluster_region missing)"
        set FAIL_COUNT (math $FAIL_COUNT + 1)
        continue
    end
    
    # Extract environment for context alias
    set -l ENVIRONMENT (echo "$CLUSTER_ITEM" | sed 's/^EKS-//' | cut -d'-' -f1)
    set -l CONTEXT_ALIAS "$ENVIRONMENT-$CLUSTER_NAME"
    
    echo "   Name: $CLUSTER_NAME"
    echo "   Region: $CLUSTER_REGION"
    echo "   Context: $CONTEXT_ALIAS"
    
    # Update kubeconfig
    if aws eks update-kubeconfig \
        --region "$CLUSTER_REGION" \
        --name "$CLUSTER_NAME" \
        --alias "$CONTEXT_ALIAS" 2>/dev/null
        echo "   ✅ Successfully configured"
        set SUCCESS_COUNT (math $SUCCESS_COUNT + 1)
    else
        echo "   ❌ Failed to configure (check AWS permissions or cluster availability)"
        set FAIL_COUNT (math $FAIL_COUNT + 1)
    end
end

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   ✅ Configured: $SUCCESS_COUNT"
echo "   ❌ Failed: $FAIL_COUNT"
echo ""

# Show available contexts
echo "📋 Available kubectl contexts:"
kubectl config get-contexts
echo ""

# Set default context if only one cluster was configured
if test $SUCCESS_COUNT -eq 1
    set -l FIRST_CONTEXT (kubectl config get-contexts -o name | head -1)
    kubectl config use-context "$FIRST_CONTEXT"
    echo "🎯 Default context set to: $FIRST_CONTEXT"
else
    echo "💡 Tip: Switch contexts with:"
    echo "   kubectl config use-context <context-name>"
    echo "   kubectl ctx  (if using kubectx plugin)"
end

echo ""
echo "✅ Setup complete!"
```

### Phase 3: IAM Access Configuration (This Repository)

#### 3.1 EKS Access Entry for SSO Users

Add access entries for SSO users/roles to access the cluster:

```hcl
# In terraform/env-development/platform-layer/eks-auto-mode/access.tf

# Allow SSO administrators to access EKS
resource "aws_eks_access_entry" "sso_admins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_admins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.sso_admins.principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
```

#### 3.2 Variable for Admin Principals

```hcl
variable "eks_admin_principals" {
  description = "List of IAM principals (roles/users) that should have admin access to EKS"
  type        = list(string)
  default     = []
}
```

### Phase 4: Workflow Documentation

#### Daily Workflow

```text
1. Open devcontainer in eks-admin repository
2. Ensure 1Password service account token is set:
   set -Ux OP_SERVICE_ACCOUNT_TOKEN "xxxx"
3. Connect to desired cluster:
   ./scripts/connect.sh development
4. If AWS SSO session expired, authenticate:
   aws sso login
5. Use kubectl normally:
   kubectl get pods -A
   k9s
```

#### Context Switching

```bash
# List available contexts
kubectl config get-contexts

# Switch contexts
kubectl config use-context development-dev-eks-auto-mode

# Or use kubectx (via krew)
kubectl ctx
```

## Security Considerations

### What's Stored in 1Password

| Data | Sensitivity | Stored in 1Password? |
|------|-------------|---------------------|
| Cluster name | Low | ✅ Yes |
| Cluster endpoint | Low | ✅ Yes |
| Cluster region | Low | ✅ Yes |
| AWS account ID | Low | ✅ Yes (convenience) |
| Cluster CA data | Medium | ❌ No (retrieved via AWS API) |
| AWS credentials | High | ❌ No (use SSO) |
| Kubectl tokens | High | ❌ No (short-lived, dynamic) |

### Authentication Flow

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   1Password     │     │    AWS SSO      │     │   EKS Cluster   │
│   (Cluster Info)│     │   (Auth)        │     │   (API)         │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  1. Get cluster info  │                       │
         │◄──────────────────────│                       │
         │                       │                       │
         │                       │  2. SSO Login         │
         │                       │◄──────────────────────│
         │                       │                       │
         │                       │  3. Get STS Token     │
         │                       │──────────────────────►│
         │                       │                       │
         │                       │  4. kubectl commands  │
         │                       │──────────────────────►│
         │                       │                       │
```

### Principle of Least Privilege

- **1Password access**: Read-only access to cluster connection details
- **AWS SSO**: Time-limited session (configurable, default 1-8 hours)
- **EKS access**: RBAC-controlled within cluster
- **No persistent credentials**: All tokens are short-lived and automatically rotated

## Consequences

### Positive

- **No long-lived secrets**: All credentials are short-lived and auto-rotated
- **Audit trail**: AWS CloudTrail logs all EKS API access
- **Centralized identity**: Uses existing AWS SSO/IAM Identity Center
- **Secure by default**: Cluster CA verified via AWS API, not stored locally
- **Multi-cluster ready**: Easy to add new clusters to 1Password
- **Familiar pattern**: Mirrors homelab approach with 1Password + devcontainer

### Negative

- **AWS SSO dependency**: Requires SSO session for access
- **Internet required**: Cannot work offline
- **Initial setup complexity**: More moving parts than simple kubeconfig storage
- **SSO session expiry**: May need to re-authenticate during long sessions

### Neutral

- **Two repositories**: Clear separation but requires coordination
- **1Password dependency**: Extends existing dependency
- **Learning curve**: Team needs to understand AWS SSO + EKS access patterns

## Alternatives Not Chosen

### Static Kubeconfig with AWS IAM Authenticator

Considered storing a static kubeconfig that uses `aws eks get-token` for authentication. Rejected because:

- Still requires AWS credentials management
- Kubeconfig contains cluster CA (sensitive)
- More complex than using `aws eks update-kubeconfig` dynamically

### Kubernetes Service Account Tokens

Considered creating long-lived Kubernetes service account tokens. Rejected because:

- Security risk with long-lived tokens
- Token rotation is manual
- Bypasses AWS IAM audit trail

### Bastion Host Approach

Considered setting up a bastion host with kubectl pre-configured. Rejected because:

- Additional infrastructure to manage
- Doesn't align with devcontainer workflow
- Higher operational cost

## Related Decisions

- **ADR-005**: Secrets Manager (AWS Secrets Manager for infrastructure secrets)
- **ADR-010**: AWS IAM Role Structure (defines IAM patterns)
- **ADR-013**: GHA IAM Role for EKS (CI/CD access patterns)
- **ADR-015**: User Personas AWS SSO EKS (user access personas)

## Future Enhancements

1. **GitHub Codespaces integration**: Add Codespaces configuration for cloud-based access
2. **Automated cluster discovery**: Script to list all EKS clusters in 1Password
3. **ArgoCD integration**: Consider GitOps workflow from admin repository
4. **Multi-cloud support**: Extend pattern to other cloud providers (GKE, AKS)
5. **Terraform 1Password provider**: Automate cluster details → 1Password

## References

- [AWS EKS Authentication](https://docs.aws.amazon.com/eks/latest/userguide/cluster-auth.html)
- [AWS EKS Access Management](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [AWS SSO with kubectl](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
- [kubectl Configuration](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Existing Homelab Admin Pattern](https://github.com/dr3dr3/k8s-homelab-admin)

---

**Date**: 2025-12-01
**Author**: Platform Engineering Team
**Status**: Approved
**Version**: 1.0
