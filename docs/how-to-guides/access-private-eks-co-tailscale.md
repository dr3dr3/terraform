# How-To Guide: Accessing Private EKS Control Plane via Tailscale

## Overview

This guide covers accessing an AWS EKS cluster with a private-only endpoint using Tailscale subnet router. This setup eliminates the need for NAT Gateways, bastion hosts, or VPN servers while maintaining secure access to your cluster.

## Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl installed (v1.28 or later recommended)
- Tailscale installed and authenticated on your local machine
- Tailscale auth key with subnet router permissions
- Terraform deployed EKS cluster with private endpoint only

## Architecture Summary

```text
Your Device 
→ Tailscale Client 
→ Tailnet 
→ Tailscale Subnet Router Pod 
→ EKS Control Plane
→ Cluster Services
```

The Tailscale subnet router advertises your EKS cluster's pod and service CIDRs to your tailnet, allowing direct access to the cluster as if you were inside the VPC.

## Initial Setup

### Step 1: Generate Tailscale Auth Key

1. Visit [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Generate a new auth key with these settings:
   - **Reusable**: Yes (allows recreation of pod if needed)
   - **Ephemeral**: No (keeps node in devices list)
   - **Preauthorized**: Yes
   - **Tags**: Add `tag:k8s` for organization
   - **Expiry**: 90 days (or longer for learning environment)

3. Copy the generated key (starts with `tskey-auth-...`)

### Step 2: Store Auth Key in Kubernetes Secret

Once your EKS cluster is deployed, create the Tailscale auth secret:

```bash
# Set your cluster name
export CLUSTER_NAME="my-eks-cluster"
export AWS_REGION="ap-southeast-2"

# Update kubeconfig (this will work once Tailscale is set up)
# For initial setup, you may need temporary public access or use AWS CloudShell
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Create tailscale namespace
kubectl create namespace tailscale

# Create secret with your auth key
kubectl create secret generic tailscale-auth \
  --from-literal=TS_AUTH_KEY=tskey-auth-xxxxx-yyyyyy \
  -n tailscale
```

**Note**: For initial setup with a private-only cluster, you'll need to either:

- Temporarily enable public endpoint access, or
- Use AWS CloudShell (has VPC access), or
- Use AWS Systems Manager Session Manager to access a node

### Step 3: Determine Your Cluster CIDRs

You need to know your pod and service CIDRs to configure the subnet router:

```bash
# Get cluster CIDR information
aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query 'cluster.kubernetesNetworkConfig' --output json

# Example output:
# {
#   "serviceIpv4Cidr": "172.20.0.0/16",
#   "ipFamily": "ipv4"
# }

# Pod CIDR is typically set in VPC CNI configuration
kubectl get daemonset aws-node -n kube-system -o yaml | grep CLUSTER_CIDR

# Or check VPC CNI ConfigMap
kubectl get configmap amazon-vpc-cni -n kube-system -o yaml
```

Common default CIDRs:

- **Service CIDR**: `172.20.0.0/16`
- **Pod CIDR**: `10.100.0.0/16` (or your VPC secondary CIDR)

### Step 4: Deploy Tailscale Subnet Router

Create the deployment manifest (update CIDRs to match your cluster):

```yaml
# tailscale-subnet-router.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tailscale-router
  namespace: tailscale

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tailscale-router
  namespace: tailscale
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tailscale-router
  namespace: tailscale
subjects:
- kind: ServiceAccount
  name: tailscale-router
  namespace: tailscale
roleRef:
  kind: Role
  name: tailscale-router
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tailscale-subnet-router
  namespace: tailscale
  labels:
    app: tailscale-router
spec:
  replicas: 1
  strategy:
    type: Recreate  # Ensure only one instance at a time
  selector:
    matchLabels:
      app: tailscale-router
  template:
    metadata:
      labels:
        app: tailscale-router
    spec:
      serviceAccountName: tailscale-router
      initContainers:
      - name: sysctler
        image: busybox:1.36
        securityContext:
          privileged: true
        command: ["/bin/sh"]
        args:
          - -c
          - |
            sysctl -w net.ipv4.ip_forward=1
            sysctl -w net.ipv6.conf.all.forwarding=1
        resources:
          requests:
            cpu: 1m
            memory: 1Mi
          limits:
            cpu: 10m
            memory: 10Mi
      containers:
      - name: tailscale
        image: tailscale/tailscale:v1.56.1  # Pin version for stability
        imagePullPolicy: IfNotPresent
        env:
        - name: TS_KUBE_SECRET
          value: "tailscale-state"
        - name: TS_USERSPACE
          value: "false"
        - name: TS_AUTH_KEY
          valueFrom:
            secretKeyRef:
              name: tailscale-auth
              key: TS_AUTH_KEY
        - name: TS_ROUTES
          value: "10.100.0.0/16,172.20.0.0/16"  # UPDATE THESE TO YOUR CIDRs
        - name: TS_STATE_DIR
          value: "/var/lib/tailscale"
        - name: TS_ACCEPT_DNS
          value: "false"
        - name: TS_EXTRA_ARGS
          value: "--advertise-tags=tag:k8s --hostname=eks-subnet-router"
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        volumeMounts:
        - name: dev-net-tun
          mountPath: /dev/net/tun
      volumes:
      - name: dev-net-tun
        hostPath:
          path: /dev/net/tun
      # Prefer nodes with more resources for subnet router
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - t3.medium
                - t3.large
```

Deploy the subnet router:

```bash
kubectl apply -f tailscale-subnet-router.yaml

# Verify deployment
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app=tailscale-router -f
```

### Step 5: Approve Subnet Routes in Tailscale Admin

1. Go to [Tailscale Machines](https://login.tailscale.com/admin/machines)
2. Find your new device (named `eks-subnet-router`)
3. Click the three dots menu → **Edit route settings**
4. Approve the advertised routes:
   - `10.100.0.0/16` (pod CIDR)
   - `172.20.0.0/16` (service CIDR)
5. Click **Save**

### Step 6: Verify Connectivity

Test that you can reach cluster resources:

```bash
# Ensure you're connected to your tailnet
tailscale status

# Test DNS resolution of EKS endpoint
# Get your cluster endpoint
aws eks describe-cluster --name $CLUSTER_NAME \
  --query 'cluster.endpoint' --output text

# Should show something like:
# https://ABC123.gr7.ap-southeast-2.eks.amazonaws.com

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Test kubectl access
kubectl get nodes
kubectl get pods -A

# Test accessing a service IP directly
kubectl get svc -n kube-system
# Try to reach kube-dns
kubectl get svc kube-dns -n kube-system
# Note the ClusterIP (e.g., 172.20.0.10)

# Test connectivity (from your local machine)
curl -k https://172.20.0.10:53
# Or use nslookup
nslookup kubernetes.default.svc.cluster.local 172.20.0.10
```

## Daily Usage

### Accessing the Cluster

1. **Ensure Tailscale is running** on your device:

   ```bash
   tailscale status
   ```

2. **Update kubeconfig** (if not already configured):

   ```bash
   aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
   ```

3. **Use kubectl normally**:

   ```bash
   kubectl get pods -A
   kubectl describe node
   ```

### Port Forwarding to Services

Access web applications or services:

```bash
# Forward a deployment to local port
kubectl port-forward -n default deployment/my-app 8080:80

# Access in browser
open http://localhost:8080

# Forward a service
kubectl port-forward -n default svc/my-service 8080:80
```

### Accessing Services Directly

Because subnet routes are advertised, you can access services directly by their ClusterIP:

```bash
# Get service IP
kubectl get svc my-service -n default
# NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# my-service   ClusterIP   172.20.15.123   <none>        80/TCP

# Access directly (if HTTP)
curl http://172.20.15.123

# Or add to /etc/hosts for easier access
# 172.20.15.123 my-service.local
```

### Accessing from Other Tailnet Devices

Any device on your tailnet can access the cluster:

```bash
# From your homelab server
curl http://172.20.15.123

# Or configure kubectl on homelab
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get pods -A
```

## Troubleshooting

### Cannot Connect to EKS Control Plane

**Symptoms**: `kubectl` commands timeout or show connection refused

**Solutions**:

1. Verify Tailscale is connected:

   ```bash
   tailscale status
   # Should show "logged in" and list of devices
   ```

2. Check subnet routes are approved:

   ```bash
   tailscale status --json | jq '.Self.AllowedIPs'
   # Should include your cluster CIDRs
   ```

3. Verify subnet router pod is running:

   ```bash
   kubectl get pods -n tailscale
   kubectl logs -n tailscale -l app=tailscale-router
   ```

4. Test basic network connectivity:

   ```bash
   # Get EKS endpoint
   aws eks describe-cluster --name $CLUSTER_NAME \
     --query 'cluster.endpoint' --output text
   
   # Try to resolve it
   nslookup ABC123.gr7.ap-southeast-2.eks.amazonaws.com
   
   # Try to reach it (should get TLS error, but that means network works)
   curl -v https://ABC123.gr7.ap-southeast-2.eks.amazonaws.com
   ```

### Subnet Router Pod Won't Start

**Symptoms**: Pod in CrashLoopBackOff or ImagePullBackOff

**Solutions**:

1. Check pod events:

   ```bash
   kubectl describe pod -n tailscale -l app=tailscale-router
   ```

2. Verify VPC endpoints for ECR:

   ```bash
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.$AWS_REGION.ecr.dkr" \
     --query 'VpcEndpoints[0].State'
   ```

3. Check node can pull images:

   ```bash
   # Exec into a test pod
   kubectl run test --image=busybox --rm -it -- sh
   
   # Or check node logs (via Systems Manager)
   aws ssm start-session --target i-xxxxx
   journalctl -u kubelet
   ```

4. Verify auth key secret:

   ```bash
   kubectl get secret tailscale-auth -n tailscale -o yaml
   # Check that TS_AUTH_KEY is present and valid
   ```

### Routes Not Appearing in Tailscale

**Symptoms**: Routes not visible in Tailscale admin or not working

**Solutions**:

1. Check pod logs for route advertisement:

   ```bash
   kubectl logs -n tailscale -l app=tailscale-router | grep -i route
   ```

2. Verify `TS_ROUTES` environment variable:

   ```bash
   kubectl get deployment tailscale-subnet-router -n tailscale -o yaml | grep TS_ROUTES
   ```

3. Manually approve routes in admin console
   - Visit <https://login.tailscale.com/admin/machines>
   - Find your subnet router device
   - Edit route settings and approve

4. Check pod has NET_ADMIN capability:

   ```bash
   kubectl get pod -n tailscale -l app=tailscale-router -o yaml | grep -A5 securityContext
   ```

### High CPU or Memory Usage

**Symptoms**: Subnet router pod consuming excessive resources

**Solutions**:

1. Check current resource usage:

   ```bash
   kubectl top pod -n tailscale
   ```

2. Review Tailscale logs for errors:

   ```bash
   kubectl logs -n tailscale -l app=tailscale-router --tail=100
   ```

3. Adjust resource limits if needed:

   ```yaml
   resources:
     requests:
       cpu: 200m
       memory: 256Mi
     limits:
       cpu: 1000m
       memory: 512Mi
   ```

4. Check for excessive traffic through router:

   ```bash
   # Check network traffic on pod
   kubectl exec -n tailscale -it $(kubectl get pod -n tailscale -l app=tailscale-router -o name) -- netstat -s
   ```

## Advanced Configuration

### Using Tailscale ACLs for Access Control

Restrict which tailnet users/devices can access cluster networks:

```json
// In Tailscale ACL editor
{
  "tagOwners": {
    "tag:k8s": ["your-email@example.com"],
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s:*"]
    },
    {
      "action": "accept",
      "src": ["tag:homelab"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

### Monitoring Subnet Router Health

Create a simple monitoring setup:

```yaml
# monitoring/servicemonitor.yaml
apiVersion: v1
kind: Service
metadata:
  name: tailscale-router-metrics
  namespace: tailscale
  labels:
    app: tailscale-router
spec:
  selector:
    app: tailscale-router
  ports:
  - name: metrics
    port: 9001
    targetPort: 9001
```

### High Availability (Optional)

For critical learning environments, run multiple replicas:

```yaml
spec:
  replicas: 2  # Run 2 subnet routers
  
  # Add pod anti-affinity to spread across nodes
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: tailscale-router
          topologyKey: kubernetes.io/hostname
```

**Note**: Each replica will register as a separate device in Tailscale. You'll need to approve routes for each.

## Best Practices

1. **Pin Tailscale image version**: Avoid `latest` tag to prevent unexpected changes
2. **Use meaningful hostnames**: Set `--hostname` in `TS_EXTRA_ARGS` for easy identification
3. **Tag your devices**: Use `--advertise-tags=tag:k8s` for ACL management
4. **Monitor auth key expiry**: Rotate keys before 90-day expiration
5. **Document your CIDRs**: Keep track of pod/service CIDRs in your Terraform configs
6. **Test failover**: Periodically delete the subnet router pod to verify it recreates successfully
7. **Resource right-sizing**: Monitor and adjust CPU/memory based on actual usage

## Cost Comparison

### Traditional Setup (NAT Gateway)

```text
Monthly costs:
- NAT Gateway (2 AZs): $64.80
- Data processing (100GB): $4.50
- Public ALB (if used): $16.20
Total: ~$85/month or $1,020/year
```

### Tailscale Setup (This Guide)

```text
Monthly costs:
- Tailscale Personal: $0 (free)
- VPC Endpoints (5 endpoints): ~$36.50
- Data processing (minimal): ~$1
Total: ~$38/month or $456/year

Savings: ~$47/month or $564/year
```

## Security Considerations

1. **Auth Key Security**
   - Store auth keys as Kubernetes secrets (never in code)
   - Rotate keys regularly
   - Use ephemeral keys for temporary access

2. **Network Isolation**
   - Subnet router only advertises specific CIDRs
   - No exit node capabilities (blocks general internet routing)
   - Tailscale ACLs provide additional access control

3. **Audit Logging**
   - Monitor Tailscale device connections in admin console
   - Enable EKS audit logging for cluster access
   - Review kubectl command history periodically

4. **Pod Security**
   - Subnet router requires NET_ADMIN (necessary for routing)
   - Run in dedicated namespace
   - Consider Pod Security Standards enforcement

## Migration Path

### From Public to Private Cluster

If transitioning an existing public cluster:

1. Deploy Tailscale subnet router while public endpoint is active
2. Verify access through Tailscale works
3. Update cluster to private endpoint only:

   ```bash
   aws eks update-cluster-config --name $CLUSTER_NAME \
     --resources-vpc-config endpointPublicAccess=false,endpointPrivateAccess=true
   ```

4. Remove NAT Gateway (via Terraform)
5. Add VPC endpoints (via Terraform)

### To Production-Ready Setup

When ready to use patterns in production:

1. Enable public endpoint with authorized networks
2. Add NAT Gateway for outbound internet (if required)
3. Deploy Tailscale operator for service-level exposure
4. Implement proper ingress controller (nginx/ALB)
5. Add certificate management (cert-manager)

## Related Resources

- **ADR**: [EKS Private Networking with Tailscale](./adr-eks-private-tailscale.md)
- **Tailscale Docs**: [Subnet Routers](https://tailscale.com/kb/1019/subnets)
- **AWS Docs**: [EKS Private Clusters](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)
- **AWS Docs**: [VPC Endpoints for EKS](https://docs.aws.amazon.com/eks/latest/userguide/vpc-interface-endpoints.html)

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2024-12-08 | André | Initial guide created |

## Questions or Issues?

If you encounter issues not covered in this guide:

1. Check Tailscale community forums
2. Review EKS documentation for private clusters
3. Check VPC endpoint connectivity
4. Verify security group rules allow traffic between subnets

For personal infrastructure, document learnings in your GitHub repo for future reference.
