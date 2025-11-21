# 🚀 Getting Started with Your EKS Learning Cluster

## 📦 What You've Got

A complete, production-quality Terraform configuration for deploying a **simple, cost-effective EKS cluster** for learning purposes.

### Files in This Package

```
eks-learning-cluster/
├── main.tf                  # Main Terraform configuration (VPC, EKS, IAM)
├── outputs.tf              # Output values after deployment
├── .gitignore              # Git ignore patterns
├── sample-app.yaml         # Sample nginx application for testing
├── README.md               # Comprehensive documentation (START HERE!)
├── SUMMARY.md              # Quick overview and checklist
└── QUICK_REFERENCE.md      # Common kubectl commands
```

## ⚡ Quick Start (5 minutes)

### 1. Update Configuration
Open `main.tf` and update line 15:
```hcl
organization = "YOUR_ORG_NAME"  # Change this to your Terraform Cloud org
```

### 2. Deploy
```bash
# Initialize
terraform init

# Deploy (takes ~15-20 minutes)
terraform apply
```

### 3. Connect
```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name learning-eks

# Verify
kubectl get nodes
```

### 4. Test
```bash
# Deploy sample app
kubectl apply -f sample-app.yaml

# Check status
kubectl get pods
kubectl get svc
```

### 5. Cleanup (IMPORTANT!)
```bash
# Delete LoadBalancers first
kubectl delete svc -A --field-selector spec.type=LoadBalancer

# Destroy cluster
terraform destroy
```

## 📖 Documentation Guide

### For First-Time Users
**Start here:** `README.md`
- Complete setup instructions
- Architecture overview
- Cost estimates
- Troubleshooting guide

### For Quick Reference
**Use:** `QUICK_REFERENCE.md`
- Essential kubectl commands
- Troubleshooting commands
- IAM role usage
- Cost management tips

### For Overview
**Read:** `SUMMARY.md`
- What you're getting
- Infrastructure components
- Security configuration
- Learning path

## 💡 Key Points to Remember

### ✅ This Cluster Is
- Simple and easy to understand
- Cost-optimized (~$0.17/hour, ~$4/day)
- Secure with AWS best practices
- Perfect for learning Kubernetes
- Easy to deploy and destroy

### ❌ This Cluster Is NOT
- Production-ready (single AZ, spot instances)
- Highly available
- Publicly accessible (private endpoint only)
- Expensive to run (if you destroy after use)

## 🎯 What's Configured

### Infrastructure
- ✅ VPC with public and private subnets
- ✅ EKS cluster v1.31 (latest Kubernetes)
- ✅ Managed node group with spot instances
- ✅ KMS encryption for secrets
- ✅ CloudWatch logging
- ✅ All necessary security groups

### IAM & Access
- ✅ Cluster IAM role
- ✅ Node IAM role  
- ✅ Admin access role (full permissions)
- ✅ Read-only role (view-only)
- ✅ IRSA enabled (pod-level permissions)

### Networking
- ✅ Private cluster endpoint (secure)
- ✅ NAT Gateway for internet access
- ✅ Proper security group rules
- ✅ VPC CNI plugin configured

## 💰 Cost Awareness

### Estimated Costs
- **Per Hour**: ~$0.17
- **Per Day**: ~$4.56
- **Per Month** (24/7): ~$138
- **Typical Usage** (2 hrs/day): ~$10/month

### 🚨 To Keep Costs Low
1. **Destroy when not in use**: `terraform destroy`
2. **Delete LoadBalancers first**: They cost extra
3. **Monitor AWS costs**: Use Cost Explorer
4. **Set billing alerts**: Get notified early

## 🔒 Security Notes

### What's Secure
- ✅ Private API endpoint (no internet access)
- ✅ Encrypted secrets (KMS)
- ✅ IMDSv2 required on nodes
- ✅ Least privilege security groups
- ✅ IAM-based authentication

### Access Options
Since the cluster is **private only**, you need ONE of:
1. **Bastion host** in public subnet (recommended)
2. **VPN connection** to VPC
3. **Temporary public access** (learning only, not recommended)

## 🎓 Learning Path

### Day 1 - Basics
- Deploy cluster
- Learn kubectl basics
- Deploy sample application
- Explore pods and services

### Week 1 - Core Concepts
- Deployments and ReplicaSets
- Services and networking
- ConfigMaps and Secrets
- Namespaces and labels

### Week 2 - Operations
- Scaling applications
- Rolling updates
- Resource management
- Basic troubleshooting

### Month 1 - Advanced
- IRSA and AWS integration
- Ingress controllers
- Monitoring and logging
- RBAC and security

## ⚠️ Before You Deploy

### Checklist
- [ ] Updated Terraform Cloud org name in `main.tf`
- [ ] AWS credentials configured
- [ ] Terraform Cloud workspace exists
- [ ] Understanding cluster is private only
- [ ] Aware of costs (~$4/day)
- [ ] Plan to destroy after learning sessions

## 🆘 Need Help?

### Documentation
1. **README.md** - Comprehensive guide
2. **SUMMARY.md** - Quick overview
3. **QUICK_REFERENCE.md** - Command reference

### Common Issues
- **Can't connect**: Cluster is private, need VPN/bastion
- **High costs**: Forgot to destroy, check LoadBalancers
- **Pods pending**: Check node resources

### Resources
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## 🎉 You're All Set!

This configuration is:
- ✅ **Ready to deploy** - Just update org name and run
- ✅ **Well documented** - Everything explained
- ✅ **Secure** - AWS best practices implemented
- ✅ **Cost-effective** - ~$0.17/hour
- ✅ **Educational** - Perfect for learning

## 🚀 Next Steps

1. Read `README.md` thoroughly
2. Update `main.tf` with your Terraform Cloud org
3. Run `terraform init`
4. Run `terraform apply`
5. Configure kubectl
6. Deploy sample app
7. Start learning!
8. **Don't forget to destroy when done!**

---

**Ready to learn Kubernetes?** Start with the README.md and begin your journey! 🎓

**Remember:** This is a learning environment. Experiment freely, but always `terraform destroy` when you're done to avoid unnecessary costs.

**Happy Learning!** 🚀