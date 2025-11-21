# Simple EKS Cluster for Learning

This Terraform configuration creates a **simple, cost-effective** EKS cluster in AWS Sydney region (ap-southeast-2) for learning and experimentation.

## 🎯 Design Decisions

### Cost Optimization
- **Single Availability Zone**: Reduces NAT Gateway and data transfer costs
- **Spot Instances**: t3a.medium/t3.medium spot instances provide ~70% cost savings
- **Single NAT Gateway**: One NAT gateway instead of one per AZ
- **Minimal Node Count**: Starts with 1 node, can scale to 2
- **Small Disk Size**: 20GB EBS volumes
- **Limited Control Plane Logging**: Only essential logs (api, audit, authenticator)

### Security Best Practices
- **Private Cluster Access Only**: API endpoint not exposed to internet
- **IMDSv2 Required**: Instance metadata service v2 enforced
- **Secrets Encryption**: Kubernetes secrets encrypted at rest with KMS
- **Pod Security**: Ready for pod security policies/standards
- **Network Segmentation**: Public and private subnets with proper routing
- **IAM Roles**: Separate admin and read-only roles with appropriate policies

### Kubernetes Configuration
- **Latest Version**: Kubernetes 1.31 (latest as of Oct 2025)
- **EKS Addons**: CoreDNS, kube-proxy, VPC CNI, Pod Identity Agent
- **IRSA Enabled**: IAM Roles for Service Accounts for pod-level permissions
- **Managed Node Group**: AWS-managed nodes for easier operation

## 📋 Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **Terraform Cloud**: Account configured with workspace
3. **OIDC Integration**: Already configured in your devcontainer
4. **AWS CLI**: For kubectl configuration post-deployment

## 🚀 Deployment

### Step 1: Update Configuration

Edit `main.tf` and update the Terraform Cloud backend:

```hcl
cloud {
  organization = "YOUR_ORG_NAME"  # Update this
  workspaces {
    name = "eks-learning"
  }
}
```

### Step 2: Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the cluster (takes ~15-20 minutes)
terraform apply
```

### Step 3: Configure kubectl

After deployment completes, configure kubectl:

```bash
# Get the command from Terraform output
terraform output configure_kubectl

# Run the command (example)
aws eks update-kubeconfig --region ap-southeast-2 --name learning-eks
```

### Step 4: Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

## 🔐 IAM Roles and Access

### Admin Role
- **ARN**: Output as `eks_admin_role_arn`
- **Permissions**: Full cluster admin access
- **Use Case**: Day-to-day cluster management via kubectl

### Read-Only Role
- **ARN**: Output as `eks_readonly_role_arn`
- **Permissions**: View-only access to cluster resources
- **Use Case**: Console access, monitoring, auditing

### Assuming Roles

To use these roles from AWS CLI/kubectl:

```bash
# Assume admin role
aws sts assume-role --role-arn <admin-role-arn> --role-session-name eks-admin-session

# Assume read-only role
aws sts assume-role --role-arn <readonly-role-arn> --role-session-name eks-readonly-session
```

## 🌐 Accessing Your Cluster

Since the cluster API is **private only**, you have two options:

### Option 1: Bastion Host (Recommended for Production)
Deploy a bastion host in the public subnet:

```bash
# Create a bastion EC2 instance in the public subnet
# Configure security groups to allow SSH
# Install kubectl on bastion
# Configure kubeconfig on bastion
```

### Option 2: VPN/Direct Connect (Enterprise)
- Set up AWS Client VPN
- Configure Direct Connect
- Use AWS Systems Manager Session Manager

### Option 3: Temporarily Enable Public Access (Learning Only)

**⚠️ Only for learning purposes - not recommended for production!**

Edit `main.tf` and change:
```hcl
cluster_endpoint_public_access  = true
```

Then run `terraform apply` and restrict access:
```hcl
cluster_endpoint_public_access_cidrs = ["YOUR.IP.ADDRESS/32"]
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                  VPC (10.0.0.0/16)              │
│                                                  │
│  ┌──────────────────┐      ┌─────────────────┐ │
│  │  Public Subnet   │      │ Private Subnet  │ │
│  │  10.0.101.0/24   │      │  10.0.1.0/24    │ │
│  │                  │      │                 │ │
│  │  - NAT Gateway   │◄─────┤  - EKS Nodes    │ │
│  │  - Internet GW   │      │  - Worker Pods  │ │
│  └──────────────────┘      └─────────────────┘ │
│                                                  │
│              ┌─────────────────────┐            │
│              │   EKS Control Plane │            │
│              │    (AWS Managed)    │            │
│              │   - Private API     │            │
│              │   - Encrypted       │            │
│              └─────────────────────┘            │
└─────────────────────────────────────────────────┘
```

## 📦 What Gets Created

### Networking
- 1x VPC with DNS support
- 1x Public subnet
- 1x Private subnet
- 1x Internet Gateway
- 1x NAT Gateway
- Route tables and associations

### EKS Cluster
- EKS control plane (v1.31)
- KMS key for secrets encryption
- CloudWatch log group
- OIDC identity provider
- Security groups

### Node Groups
- 1x Managed node group
- Spot instance (t3a.medium/t3.medium)
- Auto Scaling Group (min: 1, max: 2)
- Launch template
- IAM role and policies

### IAM Resources
- Cluster IAM role
- Node IAM role
- Admin access role
- Read-only access role
- Associated policies

### EKS Addons
- CoreDNS
- kube-proxy
- VPC CNI
- Pod Identity Agent

## 💰 Cost Estimates

**Approximate hourly costs (Sydney region):**

| Resource | Cost/Hour | Cost/Day | Cost/Month |
|----------|-----------|----------|------------|
| EKS Control Plane | $0.10 | $2.40 | $73 |
| t3a.medium Spot | $0.01 | $0.24 | $7 |
| NAT Gateway | $0.059 | $1.42 | $43 |
| Data Transfer | Variable | ~$0.50 | ~$15 |
| EBS (20GB) | $0.00014 | $0.003 | $0.10 |
| **Total (approx)** | **$0.17** | **$4.10** | **$125** |

**To minimize costs:**
- Destroy when not in use: `terraform destroy`
- Only run for learning sessions
- Monitor AWS Cost Explorer

## 🧹 Cleanup

When you're done learning, destroy all resources:

```bash
# Destroy all resources
terraform destroy

# Confirm by typing 'yes'
```

**Important:** Make sure to:
1. Delete any LoadBalancers created by Kubernetes services
2. Delete any EBS volumes created by PersistentVolumeClaims
3. Check AWS Console to ensure all resources are removed

## 🎓 Learning Path

### 1. Basic Cluster Operations
```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Describe resources
kubectl describe node <node-name>
kubectl get events -A
```

### 2. Deploy a Sample Application
```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose it
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check the service
kubectl get svc
```

### 3. Work with Namespaces
```bash
# Create namespace
kubectl create namespace dev

# Deploy to namespace
kubectl run nginx --image=nginx -n dev

# List resources in namespace
kubectl get all -n dev
```

### 4. Practice IAM Roles for Service Accounts (IRSA)
```bash
# Create service account
# Annotate with IAM role
# Deploy pod using service account
# Verify pod has AWS credentials
```

### 5. Explore Networking
```bash
# Check CNI plugin
kubectl get pods -n kube-system | grep aws-node

# Inspect pod networking
kubectl get pod -o wide

# Test pod-to-pod communication
```

## 🔧 Troubleshooting

### Can't connect to cluster
- Check if you're in VPC or have VPN access (private endpoint only)
- Verify kubeconfig: `kubectl config view`
- Check IAM permissions

### Nodes not joining
- Check security groups
- Verify IAM role permissions
- Check CloudWatch logs

### Pods pending
- Check node resources: `kubectl describe node`
- Verify pod resource requests
- Check for taints/tolerations

### High costs
- Run `terraform destroy` when not in use
- Check for forgotten LoadBalancers
- Review CloudWatch logs retention

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Workshop](https://www.eksworkshop.com/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)

## ⚠️ Important Notes

1. **This is for learning only** - not production-ready
2. **Private cluster access** - requires VPN/bastion/temporary public access
3. **Spot instances** - can be interrupted with 2-minute notice
4. **Single AZ** - no high availability
5. **Destroy after use** - to avoid unnecessary costs
6. **Monitor costs** - use AWS Cost Explorer regularly

## 🤝 Contributing

This is a learning configuration. Feel free to:
- Modify instance types
- Adjust node counts
- Add more subnets
- Enable additional features
- Experiment and learn!

## 📄 License

This configuration is provided as-is for educational purposes.