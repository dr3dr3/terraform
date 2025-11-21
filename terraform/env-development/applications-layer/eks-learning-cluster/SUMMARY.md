# EKS Learning Cluster - Summary

## 🎯 What You're Getting

A **simple, cost-effective EKS cluster** designed for learning Kubernetes on AWS, optimized for:
- ✅ Learning and experimentation
- ✅ Low cost (~$4/day, ~$125/month if left running)
- ✅ Simple architecture (single AZ)
- ✅ Security best practices
- ✅ Easy to deploy and destroy

## 📁 Files Created

| File | Purpose |
|------|---------|
| `main.tf` | Main Terraform configuration (VPC, EKS, IAM roles) |
| `outputs.tf` | Output values after deployment |
| `README.md` | Comprehensive documentation and guide |
| `QUICK_REFERENCE.md` | Quick command reference |
| `sample-app.yaml` | Sample nginx application for testing |
| `.gitignore` | Git ignore file for Terraform |
| `SUMMARY.md` | This file |

## 🏗️ Infrastructure Components

### Networking (VPC Module)
- 1x VPC (10.0.0.0/16)
- 1x Public subnet (10.0.101.0/24) - Single AZ
- 1x Private subnet (10.0.1.0/24) - Single AZ
- 1x Internet Gateway
- 1x NAT Gateway (for private subnet internet access)
- Route tables and security groups

### EKS Cluster (EKS Module v21.8)
- **Kubernetes Version**: 1.31 (latest)
- **Region**: ap-southeast-2 (Sydney)
- **Endpoint**: Private only (not accessible from internet)
- **Encryption**: KMS encryption for Kubernetes secrets
- **Logging**: API, Audit, Authenticator logs to CloudWatch
- **IRSA**: Enabled (IAM Roles for Service Accounts)
- **Addons**: CoreDNS, kube-proxy, VPC CNI, Pod Identity Agent

### Node Groups
- **Type**: EKS Managed Node Group with Spot instances
- **Instance Types**: t3a.medium, t3.medium (spot)
- **Capacity**: Min: 1, Max: 2, Desired: 1
- **Disk**: 20GB EBS
- **Security**: IMDSv2 required, encrypted EBS volumes

### IAM Roles
1. **Cluster Role**: EKS cluster IAM role
2. **Node Role**: Worker nodes IAM role with necessary policies
3. **Admin Role**: Full cluster admin access via EKS access entries
4. **Read-Only Role**: View-only access for console/kubectl

## 🔒 Security Configuration

### Network Security
- ✅ Private API endpoint only (no internet exposure)
- ✅ Public and private subnet separation
- ✅ Security groups with least privilege
- ✅ Node-to-node communication allowed
- ✅ Control plane to webhook communication

### Compute Security
- ✅ IMDSv2 required (instance metadata v2)
- ✅ Encrypted EBS volumes
- ✅ Security group rules for necessary traffic only
- ✅ Latest Kubernetes version (1.31)

### Data Security
- ✅ Kubernetes secrets encrypted with KMS
- ✅ Control plane logs to CloudWatch
- ✅ VPC Flow Logs can be enabled if needed

### Access Control
- ✅ IAM-based authentication
- ✅ Separate admin and read-only roles
- ✅ EKS access entries for fine-grained control
- ✅ IRSA enabled for pod-level permissions

## 💰 Cost Breakdown (Approximate)

### Fixed Costs (per hour)
| Resource | Cost/Hour | Cost/Day | Cost/Month (730hrs) |
|----------|-----------|----------|---------------------|
| EKS Control Plane | $0.10 | $2.40 | $73.00 |
| NAT Gateway | $0.059 | $1.42 | $43.00 |
| **Subtotal** | **$0.159** | **$3.82** | **$116.00** |

### Variable Costs (per hour)
| Resource | Cost/Hour | Cost/Day | Cost/Month |
|----------|-----------|----------|------------|
| t3a.medium Spot (1 node) | ~$0.01 | ~$0.24 | ~$7.00 |
| EBS 20GB gp3 | $0.00014 | $0.003 | $0.10 |
| Data Transfer OUT | Variable | ~$0.50 | ~$15.00 |
| **Subtotal** | **~$0.01** | **~$0.74** | **~$22.00** |

### Total Estimated Costs
- **Per Hour**: ~$0.17
- **Per Day**: ~$4.56
- **Per Month** (if left running 24/7): ~$138
- **1 Hour Session**: ~$0.17

### Cost Optimization Tips
1. **Destroy when not in use**: Run `terraform destroy` after each learning session
2. **Typical usage**: 1-2 hours per day = ~$10/month
3. **Weekend projects**: Full weekend (16 hrs) = ~$2.72
4. **Monitor costs**: Use AWS Cost Explorer
5. **Set billing alerts**: Get notified if costs exceed threshold

## 🚀 Deployment Steps

### Before You Start
1. ✅ AWS account with appropriate permissions
2. ✅ Terraform Cloud account and workspace configured
3. ✅ AWS CLI installed
4. ✅ kubectl installed
5. ✅ OIDC authentication configured in devcontainer

### Step-by-Step
```bash
# 1. Update Terraform Cloud config
# Edit main.tf and set your organization name

# 2. Initialize Terraform
terraform init

# 3. Review the plan
terraform plan

# 4. Deploy (takes ~15-20 minutes)
terraform apply

# 5. Configure kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name learning-eks

# 6. Verify
kubectl get nodes
kubectl get pods -A

# 7. Deploy sample app
kubectl apply -f sample-app.yaml

# 8. When done, destroy
terraform destroy
```

## ⚠️ Important Limitations

### This is NOT Production-Ready
- ❌ Single availability zone (no HA)
- ❌ Spot instances (can be interrupted)
- ❌ Private cluster only (needs VPN/bastion)
- ❌ Minimal monitoring
- ❌ Basic security (production needs more)

### What's Missing for Production
- Multi-AZ deployment
- On-demand instances or reserved
- Comprehensive monitoring (Prometheus, Grafana)
- Log aggregation (ELK, CloudWatch Insights)
- Backup and disaster recovery
- Auto-scaling policies
- Network policies
- Pod security policies/standards
- Vulnerability scanning
- GitOps deployment pipeline
- Service mesh (optional)

## 🎓 What You'll Learn

### Kubernetes Concepts
- Pods, Deployments, Services
- Namespaces and resource organization
- ConfigMaps and Secrets
- Resource requests and limits
- Probes (liveness, readiness)
- Labels and selectors

### AWS EKS Specifics
- Managed vs self-managed node groups
- EKS addons management
- IAM roles for service accounts (IRSA)
- VPC networking with EKS
- Security groups and network policies
- Integration with AWS services

### Operations
- kubectl commands and operations
- Deploying applications
- Scaling workloads
- Troubleshooting issues
- Log aggregation
- Access control and RBAC

## 📚 Learning Resources

### Official Documentation
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

### Interactive Learning
- [Kubernetes.io Interactive Tutorial](https://kubernetes.io/docs/tutorials/)
- [EKS Workshop](https://www.eksworkshop.com/)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

### Tools to Explore
- `kubectl` - Command-line tool
- `k9s` - Terminal UI for Kubernetes
- `stern` - Multi-pod log tailing
- `kubectx/kubens` - Context and namespace switching
- `helm` - Package manager for Kubernetes

## 🔍 Next Steps

### Immediate (After Deployment)
1. ✅ Deploy sample application
2. ✅ Scale deployment up and down
3. ✅ View logs and describe resources
4. ✅ Create and use namespaces
5. ✅ Test service connectivity

### Short Term (First Week)
1. Deploy multi-tier application
2. Configure ConfigMaps and Secrets
3. Set up resource quotas
4. Create service accounts and RBAC
5. Test rolling updates

### Medium Term (First Month)
1. Integrate with AWS services (S3, RDS)
2. Set up Ingress controller
3. Implement monitoring
4. Practice troubleshooting
5. Explore Helm charts

### Long Term (Ongoing)
1. Study Kubernetes architecture
2. Learn about operators
3. Explore service mesh
4. Practice disaster recovery
5. Build CI/CD pipelines

## 🆘 Getting Help

### Troubleshooting Resources
1. Check `README.md` - Comprehensive guide
2. Check `QUICK_REFERENCE.md` - Common commands
3. Review CloudWatch logs
4. Check EKS console
5. Review security group rules

### Common Issues

**Can't connect to cluster**
- Cluster is private only - need VPN/bastion or temporary public access
- Check IAM permissions
- Verify kubeconfig

**High costs**
- Forgot to destroy cluster
- LoadBalancers left running
- Check AWS Cost Explorer

**Pods not starting**
- Check node capacity
- Verify image pull permissions
- Check resource requests

## ✅ Pre-Deployment Checklist

- [ ] Updated Terraform Cloud organization name in `main.tf`
- [ ] AWS credentials configured
- [ ] Terraform Cloud workspace created
- [ ] Plan reviewed with `terraform plan`
- [ ] Understanding that cluster is private only
- [ ] Aware of approximate costs
- [ ] Ready to learn Kubernetes!

## 🗑️ Post-Learning Checklist

- [ ] Delete all LoadBalancers: `kubectl delete svc -A --field-selector spec.type=LoadBalancer`
- [ ] Delete all PVCs: `kubectl delete pvc --all -A`
- [ ] Run `terraform destroy`
- [ ] Verify in AWS Console all resources deleted
- [ ] Check CloudWatch log groups (optional cleanup)

## 📞 Support

This is a learning configuration. For issues:
1. Review documentation files
2. Check Terraform/AWS/Kubernetes official docs
3. AWS Support (if you have a support plan)
4. Community forums and Stack Overflow

## 📝 Notes

- This configuration uses Terraform module versions that are current as of October 2025
- AWS provider version 6.19.0
- EKS module version 21.8.0
- VPC module version 6.5.0
- Kubernetes version 1.31

**Remember**: This is a learning environment. Experiment, break things, learn, and most importantly - destroy when you're done to avoid unnecessary costs!

## 🎉 You're Ready!

You now have everything you need to:
1. Deploy a simple EKS cluster
2. Learn Kubernetes fundamentals
3. Experiment with AWS services
4. Develop your cloud-native skills

**Deploy your cluster and start learning!** 🚀