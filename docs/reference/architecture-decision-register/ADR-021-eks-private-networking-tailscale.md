# ADR-021: EKS Cluster Private Networking with Tailscale

| Metadata       | Value                                              |
|----------------|---------------------------------------------------|
| **Status**     | Proposed                                          |
| **Date**       | 2025-12-08                                        |
| **Relates To** | ADR-009, ADR-011, ADR-020                         |
| **Categories** | Infrastructure, Networking, Security, Cost        |

---

## Context

Setting up AWS EKS clusters for learning and certification preparation (Kubestronaut path) with the following requirements:

- Single-user access (personal learning environment)
- Cost optimization for long-running learning infrastructure
- Security best practices without unnecessary public exposure
- Infrastructure-as-Code implementation using Terraform
- Integration with existing Tailscale tailnet used across homelab and cloud resources

### Current Cost Considerations

Standard EKS networking with public accessibility typically requires:

- NAT Gateway: ~$32-45/month per AZ (×2-3 AZs = $64-135/month)
- Public Load Balancers: ~$16-22/month per ALB/NLB
- Data transfer costs through NAT Gateway: $0.045/GB

For a learning environment that may run continuously, these costs add up significantly without providing value since only one user needs access.

### Technical Context

- **Existing infrastructure**: Tailscale already deployed across homelab (Talos Linux clusters) and personal AWS environment
- **Use case**: Learning and certification preparation, not production workloads
- **Access pattern**: Single user accessing from known devices on tailnet
- **Duration**: Long-running clusters for ongoing learning (not ephemeral)

### Internet Access Considerations

**Critical requirement**: EKS clusters need outbound internet access for:

- **Container image pulls**: Docker Hub, GitHub Container Registry, Quay, and other public registries
- **Helm chart installations**: Many charts reference external URLs for images and dependencies
- **Application functionality**: Certificate validation (OCSP), external API calls, package downloads
- **Kubernetes ecosystem**: Tools like cert-manager, external-dns, and various operators

**Without NAT Gateway**, clusters lose direct internet access. Options to restore connectivity:

1. **VPC Endpoints** - Provide access to AWS services (ECR, S3, etc.) but not public internet
2. **Tailscale Exit Node** - Route all internet traffic through a device on your tailnet
3. **Image Mirroring** - Copy all required images to private ECR (high maintenance overhead)

This ADR implements **Option 2** (Tailscale exit node) as the most practical solution for a learning environment.

### Current EKS Configuration (ADR-020)

The existing EKS Auto Mode configuration (`/terraform/env-{environment}/platform-layer/eks-auto-mode/`) includes:

- Public and private endpoints enabled
- NAT Gateway for private subnet internet access (configurable: single or per-AZ)
- Public subnets with Internet Gateway
- Cost-conscious defaults (2 AZs, single NAT Gateway in development)

Key variables from existing code:

| Variable | Development | Staging | Production |
|----------|-------------|---------|------------|
| `cluster_endpoint_public_access` | true | true | true |
| `cluster_endpoint_private_access` | true | true | true |
| `single_nat_gateway` | true | false | false |

## Decision

Implement a cost-optimized private networking option for sandbox/development EKS clusters using Tailscale subnet router, eliminating NAT Gateways when full private networking is desired.

This decision **extends** ADR-020's per-environment folder structure by adding optional networking modes that can be selected via variables, rather than creating separate Terraform configurations.

### Architecture Components

1. **EKS Control Plane**
   - Private endpoint only when `cluster_endpoint_public_access = false`
   - Accessible only from within VPC or via Tailscale subnet router
   - Uses existing `cluster_endpoint_private_access` variable (already defaults to `true`)

2. **Node Groups**
   - EKS Auto Mode handles node provisioning automatically
   - Private subnets only when NAT Gateway is removed
   - No public IP addresses assigned to nodes

3. **Tailscale Subnet Router**
   - Deployed as Kubernetes Deployment in dedicated namespace (`tailscale-system`)
   - Advertises cluster pod CIDR (`10.100.0.0/16`) and service CIDR (`172.20.0.0/16`) to tailnet
   - Single replica (sufficient for learning environment)
   - Runs with `NET_ADMIN` capabilities for IP forwarding
   - Managed via Terraform Helm provider (consistent with ADR-018 patterns)

4. **VPC Endpoints (New Resources)**
   - Gateway endpoint: S3
   - Interface endpoints: ECR (api + dkr), EC2, STS, EKS
   - Eliminates need for NAT Gateway for AWS service access

5. **No NAT Gateway (Optional Mode)**
   - New variable: `enable_nat_gateway = false`
   - AWS service access via VPC endpoints
   - Container image pulls via ECR VPC endpoint
   - Internet access for nodes/pods routed through Tailscale (if needed)

### Implementation Phases

**Phase 1**: VPC Endpoints + NAT Gateway (Baseline)

- Add VPC endpoints to existing `vpc.tf` for AWS service access
- Keep `enable_nat_gateway = true` (existing default)
- Deploy Tailscale subnet router to advertise cluster networks
- **Internet access**: Full via NAT Gateway
- **Use case**: Standard development, all Helm charts work, no restrictions
- **Cost**: ~$32/month NAT Gateway + ~$7/month VPC endpoints

**Phase 2**: Tailscale Exit Node + Remove NAT Gateway (Recommended)

- Configure development PC as Tailscale exit node (see Exit Node Setup below)
- Update Tailscale subnet router to use exit node for internet traffic
- Set `enable_nat_gateway = false` in `terraform.tfvars`
- Validate internet access through exit node: `kubectl exec -it <pod> -- curl -I https://registry.hub.docker.com`
- **Internet access**: Via Tailscale exit node on your tailnet
- **Use case**: Cost-optimized learning environment with full functionality
- **Cost**: ~$7/month VPC endpoints only
- **Savings**: ~$32/month (eliminates NAT Gateway)

**Phase 3**: ECR Image Mirroring (Optional Hardening)

- Mirror frequently-used public images to private ECR
- Reduces dependency on exit node for critical images
- Better for testing disaster recovery scenarios
- **Use case**: Advanced learning, practicing enterprise patterns
- **Trade-off**: Additional maintenance overhead vs. reliability

**Phase 4**: Tailscale Operator (Future Enhancement)

- Deploy once multiple applications are running
- Expose individual services with MagicDNS hostnames
- Better for web applications and service-to-service communication
- Aligns with ADR-019 hybrid approach (extend as needed)

## Consequences

### Positive

- **Cost Reduction**: Eliminate $32-45/month NAT Gateway costs (Phase 2)
- **Security**: Zero public exposure of cluster resources
- **Simplicity**: No ingress controllers, public load balancers, or certificate management needed
- **Consistency**: Unified access pattern across homelab and cloud infrastructure via Tailscale
- **Learning Value**: Demonstrates private cluster patterns relevant to enterprise environments
- **Flexibility**: Can still access cluster from any device on tailnet (laptop, desktop, mobile)
- **Internet Access**: Full internet connectivity via exit node (no functional limitations)
- **Bandwidth Efficiency**: VPC endpoints handle AWS traffic, exit node only for public internet

### Negative

- **Exit Node Dependency**: Cluster internet access requires exit node device to be running
- **Development PC Uptime**: If using dev PC as exit node, must be powered on for cluster internet access
- **Initial Complexity**: Additional setup compared to public cluster with NAT Gateway
- **Not Production-Representative**: Exit node pattern is learning-specific, not typical for production
- **Sharing Limitations**: Cannot easily share running applications with others outside tailnet
- **Troubleshooting**: Additional network layer to consider when debugging connectivity issues
- **Bandwidth Usage**: Internet traffic from cluster uses exit node's connection (typically minimal impact)

### Neutral

- **kubectl Access**: Requires Tailscale connection for cluster management (acceptable trade-off)
- **Image Pulls**: Public images via exit node, AWS images via VPC endpoints (best of both worlds)
- **Monitoring Access**: Prometheus, Grafana accessed via Tailscale (consistent with ADR-019 ArgoCD approach)
- **ArgoCD Integration**: Works with both EKS Capability and self-managed ArgoCD per ADR-019
- **Helm Compatibility**: All Helm charts work normally via exit node (no mirroring required)

## Tailscale Exit Node Setup

### Overview

A Tailscale exit node routes internet traffic from other devices on your tailnet through itself, acting as a gateway to the public internet. For this use case, your development PC becomes the internet gateway for the EKS cluster.

### Why Use Your Development PC as Exit Node

**Advantages:**

- Already connected to tailnet and powered on during development work
- Has reliable internet connection (home/office broadband)
- No additional infrastructure or costs
- Easy to enable/disable as needed
- Can monitor traffic through familiar desktop tools

**Considerations:**

- PC must be running and connected to tailnet for cluster internet access
- Internet traffic from cluster counts against your home/office bandwidth
- For learning workloads, bandwidth impact is typically minimal (image pulls, API calls)
- PC firewall must allow forwarding (Tailscale handles this automatically)

### Setup Steps

#### Step 1: Enable Exit Node on Development PC

**Linux (Ubuntu/Debian):**

```bash
# Enable IP forwarding (if not already enabled)
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Advertise as exit node
sudo tailscale up --advertise-exit-node
```

**macOS:**

```bash
# Advertise as exit node (IP forwarding handled by Tailscale)
tailscale up --advertise-exit-node
```

**Windows:**

```powershell
# Run in PowerShell as Administrator
tailscale up --advertise-exit-node
```

#### Step 2: Approve Exit Node in Tailscale Admin Console

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find your development PC in the machines list
3. Click the **⋯** menu → **Edit route settings**
4. Under "Exit node", click **Approve** or enable "Use as exit node"
5. Optionally enable "Allow local network access" if you want cluster to access your LAN

#### Step 3: Configure Tailscale Subnet Router to Use Exit Node

Update the Tailscale subnet router deployment in the EKS cluster:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tailscale-subnet-router
  namespace: tailscale-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tailscale-subnet-router
  template:
    metadata:
      labels:
        app: tailscale-subnet-router
    spec:
      serviceAccountName: tailscale
      containers:
      - name: tailscale
        image: tailscale/tailscale:latest
        env:
        - name: TS_AUTH_KEY
          valueFrom:
            secretKeyRef:
              name: tailscale-auth
              key: TS_AUTH_KEY
        - name: TS_ROUTES
          value: "10.100.0.0/16,172.20.0.0/16"  # Advertise pod and service CIDRs
        - name: TS_EXTRA_ARGS
          value: "--accept-routes"               # Accept exit node routes
        - name: TS_USERSPACE
          value: "false"
        - name: TS_STATE_DIR
          value: "/var/lib/tailscale"
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        volumeMounts:
        - name: dev-net-tun
          mountPath: /dev/net/tun
      volumes:
      - name: dev-net-tun
        hostPath:
          path: /dev/net/tun
```

**Key configuration:**

- `TS_EXTRA_ARGS: "--accept-routes"` - Tells the subnet router to accept routes from exit nodes
- The subnet router will automatically discover and use approved exit nodes on the tailnet

#### Step 4: Set Exit Node for Subnet Router (Alternative Method)

If you want to explicitly specify which exit node to use:

```bash
# From your development PC, get your Tailscale IP
tailscale ip -4
# Example output: 100.x.y.z

# SSH into the Tailscale subnet router pod
kubectl exec -it -n tailscale-system deployment/tailscale-subnet-router -- sh

# Inside the pod, configure to use specific exit node
tailscale up --exit-node=100.x.y.z --exit-node-allow-lan-access=false
```

#### Step 5: Verify Internet Access

Test that pods in the cluster can reach the internet:

```bash
# Test from a pod
kubectl run test-pod --image=alpine --rm -it --restart=Never -- sh

# Inside the pod:
wget -O- https://ifconfig.me          # Should show your home IP (from dev PC)
curl -I https://registry.hub.docker.com  # Should return 200 OK
ping -c 3 8.8.8.8                     # Should succeed

# Exit the pod
exit
```

### Monitoring and Troubleshooting

**Check exit node status on development PC:**

```bash
tailscale status
# Look for "exit node" in the output
```

**Check subnet router logs:**

```bash
kubectl logs -n tailscale-system deployment/tailscale-subnet-router -f
```

**Verify routing in cluster:**

```bash
kubectl exec -it <pod-name> -- ip route
# Should see default route through Tailscale interface
```

**Test DNS resolution:**

```bash
kubectl exec -it <pod-name> -- nslookup google.com
```

### Exit Node Best Practices

1. **Keep PC running during active development** - Cluster loses internet when exit node is offline
2. **Monitor bandwidth usage** - Most learning workloads use minimal bandwidth
3. **Use auth keys with proper expiry** - Regenerate Tailscale auth keys periodically
4. **Document your setup** - Note which device is the exit node for future reference
5. **Test failover** - Verify what happens when exit node goes offline (pods will lose internet but cluster remains accessible)

### Alternative Exit Node Options

**If development PC is not suitable:**

| Option | Pros | Cons | Cost |
|--------|------|------|------|
| **Homelab server** | Always-on, dedicated | Requires existing homelab | $0 (if existing) |
| **Cloud VM (t4g.nano)** | Reliable, always-on | Additional infrastructure | ~$3/month |
| **Raspberry Pi** | Low power, cheap | Limited bandwidth | ~$50 one-time |
| **Keep NAT Gateway** | No exit node needed | Doesn't achieve cost goals | ~$32/month |

## Implementation Details

### Terraform Changes (Per ADR-020 Pattern)

Following ADR-020's decision to keep per-environment folders, changes will be made to:

```text
terraform/
├── env-sandbox/
│   └── platform-layer/
│       └── eks-auto-mode/          # Add private networking option
│           ├── vpc.tf              # Add VPC endpoints, make NAT conditional
│           ├── vpc-endpoints.tf    # NEW: VPC endpoint resources
│           ├── variables.tf        # Add enable_nat_gateway, enable_vpc_endpoints
│           └── terraform.tfvars    # Configure for private mode
├── env-development/
│   └── platform-layer/
│       └── eks-auto-mode/          # Keep existing config (NAT Gateway)
└── workloads/                      # NEW: Workload-layer resources
    └── tailscale-subnet-router/    # NEW: Tailscale deployment
        ├── main.tf
        ├── variables.tf
        ├── helm.tf                 # Helm release for Tailscale
        └── README.md
```

**Note**: Per ADR-009, workload-layer resources like the Tailscale subnet router belong in a separate stack, not embedded in the EKS platform configuration. This maintains separation between platform provisioning and workload deployment.

### New Variables for vpc.tf

```hcl
# In variables.tf - add to existing variable definitions

variable "enable_nat_gateway" {
  description = <<-EOT
    [DECISION REQUIRED] Enable NAT Gateway for private subnet internet access.
    
    Considerations:
    - true:  Standard setup, ~$32-45/month per NAT Gateway
    - false: No NAT Gateway, requires VPC endpoints for AWS services
             and Tailscale for external access (cost-optimized for learning)
    
    When false, enable_vpc_endpoints should be true.
  EOT
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = <<-EOT
    Enable VPC endpoints for AWS service access without NAT Gateway.
    
    Creates endpoints for: S3, ECR, EC2, STS, EKS
    
    Cost: ~$7-10/month for interface endpoints (significantly less than NAT Gateway)
    
    Should be true when enable_nat_gateway is false.
  EOT
  type        = bool
  default     = false
}

variable "enable_private_only_mode" {
  description = <<-EOT
    Enable fully private cluster mode (no public endpoint).
    
    When true:
    - cluster_endpoint_public_access = false
    - Requires VPN/Tailscale for kubectl access
    
    Recommendation: Only enable in sandbox/dev for Tailscale testing
  EOT
  type        = bool
  default     = false
}
```

### Network Architecture Diagram

```text
                         Internet
                            ▲
                            │ (Public traffic)
                            │
                  ┌─────────┴─────────┐
                  │  Development PC   │
                  │  (Exit Node)      │
                  │  • Tailscale      │
                  │  • Home Broadband │
                  └─────────┬─────────┘
                            │
                            │ Tailscale Encrypted Tunnel
                            │
                  ┌─────────┴─────────────┐
                  │      Tailnet          │
                  │  • Dev PC (exit node) │
                  │  • Laptop             │
                  │  • Homelab            │
                  │  • EKS Subnet Router  │
                  └─────────┬─────────────┘
                            │
                            │ Tailscale Mesh Network
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ AWS VPC (10.0.0.0/16) - Per ADR-020 Environment Structure   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ Private Subnets (10.0.32.0/19, 10.0.64.0/19, ...)     │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────┐    │ │
│  │  │ EKS Auto Mode Cluster                         │    │ │
│  │  │ • Control Plane (Private Endpoint Only)      │    │ │
│  │  │ • Auto Mode Managed Nodes (No Public IPs)    │    │ │
│  │  │                                               │    │ │
│  │  │  ┌─────────────────────────────────────┐    │    │ │
│  │  │  │ Tailscale Subnet Router Pod         │    │    │ │
│  │  │  │ • Advertises: 10.100.0.0/16 (pods)  │    │    │ │
│  │  │  │ • Advertises: 172.20.0.0/16 (svcs)  │    │    │ │
│  │  │  │ • Uses: Dev PC as exit node         │    │    │ │
│  │  │  │ • Routes: Internet via tailnet      │    │    │ │
│  │  │  └─────────────────────────────────────┘    │    │ │
│  │  │                                               │    │ │
│  │  │  ┌─────────────────────────────────────┐    │    │ │
│  │  │  │ Application Pods                    │    │    │ │
│  │  │  │ • Pull images via exit node         │    │    │ │
│  │  │  │ • API calls via exit node           │    │    │ │
│  │  │  │ • AWS services via VPC endpoints    │    │    │ │
│  │  │  └─────────────────────────────────────┘    │    │ │
│  │  └──────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ VPC Endpoints (enable_vpc_endpoints = true)           │ │
│  │ • com.amazonaws.ap-southeast-2.s3 (Gateway)           │ │
│  │ • com.amazonaws.ap-southeast-2.ecr.api (Interface)    │ │
│  │ • com.amazonaws.ap-southeast-2.ecr.dkr (Interface)    │ │
│  │ • com.amazonaws.ap-southeast-2.ec2 (Interface)        │ │
│  │ • com.amazonaws.ap-southeast-2.sts (Interface)        │ │
│  │ • com.amazonaws.ap-southeast-2.eks (Interface)        │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ NO NAT Gateway (enable_nat_gateway = false)           │ │
│  │ Internet access via Tailscale exit node instead       │ │
│  │ Cost savings: ~$32-45/month                           │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Traffic Flow:
━━━━━━━━━━━━━
  kubectl commands      → Tailscale → Private EKS Endpoint
  AWS service calls     → VPC Endpoints (no internet)
  Public image pulls    → Tailscale → Dev PC → Internet
  External API calls    → Tailscale → Dev PC → Internet
```

### Access Patterns

1. **kubectl Commands**
   - Connect to tailnet
   - Use `aws eks update-kubeconfig --name cluster-name`
   - kubectl communicates via private endpoint through Tailscale subnet router

2. **Service Access**
   - ClusterIP services accessible directly via service CIDR (advertised by subnet router)
   - Use `kubectl port-forward` for local access on development PC
   - Or access via ClusterIP from other tailnet nodes (homelab, etc.)

3. **Application Deployment**
   - Services of type `ClusterIP` (no LoadBalancer needed)
   - Helm charts pull images via exit node internet connection
   - Ingress resources optional (for later Istio/Cilium learning)
   - Direct pod/service access via advertised CIDRs

4. **Container Image Pulls**
   - Public registries (Docker Hub, ghcr.io, quay.io): via exit node
   - AWS ECR: via VPC endpoint (no exit node needed)
   - All standard Kubernetes images work without mirroring

5. **Internet Access from Pods**
   - Outbound HTTPS/HTTP: routed through exit node
   - External API calls: work normally via exit node
   - Certificate validation (OCSP): works via exit node
   - DNS resolution: CoreDNS resolves via VPC DNS

6. **ArgoCD Access** (Per ADR-019)
   - If using EKS Capability: Access via AWS Console or Tailscale
   - If self-managed: Access ArgoCD UI via Tailscale subnet router
   - Sync/pull from Git repos: via exit node internet connection

## Alignment with 2026 Goals

This decision directly supports multiple 2026 objectives:

- **Kubestronaut Certification**: Provides realistic private cluster environment for CKA/CKAD/CKS preparation
- **Infrastructure as Code**: Full Terraform implementation following ADR-009 folder structure
- **Observability**: OpenTelemetry, Prometheus, Grafana accessible privately via Tailscale
- **Cost Optimization**: Significant monthly savings (aligns with ADR-011 sandbox environment cost controls)
- **GitOps**: ArgoCD deployment per ADR-018/ADR-019 patterns, simplified without public exposure concerns
- **Service Mesh**: Istio/Cilium learning without complexity of public ingress

## Environment Applicability

Per ADR-009 and ADR-011, this networking mode is most appropriate for:

| Environment | Private Mode | Rationale |
|-------------|-------------|-----------|
| `env-sandbox` | **Recommended** | Cost optimization, experimentation, ADR-011 cost controls |
| `env-development` | Optional | May prefer NAT Gateway for easier debugging |
| `env-staging` | Not Recommended | Should mirror production networking |
| `env-production` | Not Recommended | Requires standard enterprise networking |
| `env-local` | N/A | LocalStack environment, not applicable |

## Alternatives Considered

### Alternative 1: Public EKS Cluster with NAT Gateway (Current Default)

**Current implementation** in `/terraform/env-development/platform-layer/eks-auto-mode/`.

**Not rejected** - remains the default for development/staging/production per ADR-020. This ADR adds an **optional private mode** primarily for sandbox.

### Alternative 2: Public Endpoint with IP Restrictions

Use existing `cluster_endpoint_public_access_cidrs` variable to restrict access.

**Partial adoption:**

- Already available in existing code
- Useful as intermediate step, but doesn't eliminate NAT Gateway costs
- Dynamic home IP addresses create maintenance burden
- Can be combined with this ADR's approach

### Alternative 3: VPN-Based Access (OpenVPN/WireGuard)

**Rejected because:**

- Additional infrastructure to manage (OpenVPN/WireGuard server)
- Higher complexity than Tailscale
- Less integrated with existing homelab setup
- Tailscale already available and working

### Alternative 4: Bastion Host

**Rejected because:**

- Ongoing EC2 costs (~$10-20/month for t3.micro)
- Additional security surface to maintain
- More complex than Tailscale subnet router
- Less elegant than existing Tailscale infrastructure

### Alternative 5: AWS Client VPN

**Rejected because:**

- ~$72/month minimum (connection hour charges)
- More expensive than NAT Gateway for single-user access
- Overkill for personal learning environment

## References

- [EKS Private Cluster Requirements](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)
- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets)
- [Tailscale Exit Nodes](https://tailscale.com/kb/1103/exit-nodes)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [AWS VPC Endpoints for EKS](https://docs.aws.amazon.com/eks/latest/userguide/vpc-interface-endpoints.html)
- [EKS Best Practices - Networking](https://aws.github.io/aws-eks-best-practices/networking/index/)
- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)

## Related Decisions

| ADR | Relationship |
|-----|--------------|
| [ADR-003](./ADR-003-infra-layering-repository-structure.md) | Defines infrastructure layering (foundation/platform/workloads) |
| [ADR-009](./ADR-009-folder-structure.md) | Establishes `env-{environment}/{layer}-layer/{stack}/` pattern |
| [ADR-011](./ADR-011-sandbox-environment.md) | Sandbox environment cost optimization patterns |
| [ADR-017](./ADR-017-eks-1password-lifecycle-coordination.md) | EKS lifecycle coordination (Tailscale config may need similar patterns) |
| [ADR-018](./ADR-018-argocd-bootstrapping.md) | ArgoCD bootstrapping via Terraform Helm (same pattern for Tailscale) |
| [ADR-019](./ADR-019-argocd-implementation-options.md) | ArgoCD access patterns relevant for private cluster |
| [ADR-020](./ADR-020-eks-per-environment-code-structure.md) | Per-environment EKS folders; this ADR adds variables, not new folders |

## Notes

- This ADR is specific to personal learning infrastructure
- Production implementations would likely require different trade-offs
- The private networking option is additive to existing code, not a replacement
- EKS Auto Mode compatibility should be validated before removing NAT Gateway
- Cost estimates based on ap-southeast-2 (Sydney) region pricing

---

## Document Information

| Field | Value |
|-------|-------|
| **Created** | 2025-12-08 |
| **Author** | André |
| **Status** | Proposed |
| **Version** | 1.1 |
| **Last Updated** | 2025-12-08 |
