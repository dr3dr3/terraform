# EKS Learning Cluster - LocalStack Setup

## Overview

This directory contains a **simplified** Terraform configuration for creating an EKS cluster in LocalStack. This is designed for learning and local testing without AWS costs.

## Important Prerequisites

### 1. LocalStack Pro Required
⚠️ **EKS is a Pro-only feature in LocalStack**

You need a LocalStack Pro subscription and API key. Get one at: https://app.localstack.cloud/

### 2. Set Your API Key
```bash
# Add to your shell profile or export before starting
export LOCALSTACK_API_KEY="your-api-key-here"
```

### 3. Docker Running
Ensure Docker is running on your host machine.

## File Structure

- `main-localstack-simple.tf` - Simplified EKS configuration for LocalStack
- `main2.tf` - Original complex configuration (NOT recommended for LocalStack)
- `docker-compose.localstack-eks.yml` - LocalStack Pro configuration with EKS enabled

## Quick Start

### Step 1: Start LocalStack Pro with EKS

```bash
# Make sure your API key is set
echo $LOCALSTACK_API_KEY

# Start LocalStack Pro
docker compose -f docker-compose.localstack-eks.yml up -d

# Check it's running
docker compose -f docker-compose.localstack-eks.yml ps

# Check health (wait until services show "running")
curl http://localhost:4566/_localstack/health | jq
```

### Step 2: Initialize Terraform

```bash
cd /workspace/terraform/env-local/applications-layer/eks-learning-cluster

# Initialize with the simplified configuration
terraform init
```

### Step 3: Plan and Apply

```bash
# Plan (using the simplified file)
terraform plan -var-file=main-localstack-simple.tf

# Or rename the file to use it
mv main-localstack-simple.tf main.tf

# Then standard commands
terraform plan
terraform apply
```

### Step 4: Verify Resources

```bash
# Check EKS cluster
awslocal eks list-clusters
awslocal eks describe-cluster --name learning-eks

# Check VPC
awslocal ec2 describe-vpcs

# Check subnets
awslocal ec2 describe-subnets

# Check security groups
awslocal ec2 describe-security-groups
```

### Step 5: Clean Up

```bash
# Destroy Terraform resources
terraform destroy

# Stop LocalStack
docker compose -f docker-compose.localstack-eks.yml down

# (Optional) Remove volumes
docker compose -f docker-compose.localstack-eks.yml down -v
```
## Key Simplifications

### VPC Configuration
- Single VPC with basic configuration
- One private subnet, one public subnet
- Internet gateway (no NAT gateway)
- Basic routing tables
- Manual resource creation (no modules)

### IAM Roles
- Basic cluster role with inline policy
- Basic node role with inline policy
- No AWS managed policy attachments (may not exist in LocalStack)

### EKS Cluster
- Minimal configuration
- No encryption
- No add-ons
- Basic VPC config
- Public and private endpoint access

### Node Group
- Single node group
- Standard instance type (no spot)
- Basic scaling config
- No advanced features

## Known Limitations

### LocalStack EKS Support
Even with Pro, LocalStack's EKS implementation:
- May not support all Kubernetes versions
- Has limited node group features
- May not fully emulate all EKS APIs
- Cannot run actual Kubernetes workloads (it's a mock)

### Testing Strategy
1. ✅ Start with this simplified version
2. ✅ Verify basic resources are created
3. ✅ Test Terraform commands (init, plan, apply, destroy)
4. ⚠️ Don't expect to deploy actual Kubernetes workloads
5. ⚠️ Always validate final configuration against real AWS

## Troubleshooting

### "EKS service not available"
- Ensure you're using LocalStack Pro: `localstack/localstack-pro:latest`
- Verify API key is set: `echo $LOCALSTACK_API_KEY`
- Check services list includes `eks`: `curl http://localhost:4566/_localstack/health | jq '.services.eks'`

### "Invalid endpoint" errors
- Verify LocalStack is running: `docker ps | grep localstack`
- Check port 4566 is accessible: `curl http://localhost:4566/_localstack/health`
- Ensure endpoints in provider config match LocalStack URL

### Terraform apply fails
- Check LocalStack logs: `docker compose -f docker-compose.localstack-eks.yml logs -f`
- Enable debug mode: `DEBUG=1` in docker-compose file
- Start fresh: destroy all resources and restart LocalStack

### Can't connect to cluster with kubectl
- LocalStack EKS creates mock clusters that don't run real Kubernetes
- You cannot use kubectl to manage workloads in LocalStack EKS
- This is for Terraform testing only, not actual Kubernetes usage

## Next Steps

1. **Test Basic Flow**: Run through the Quick Start to verify everything works
2. **Iterate**: Make small changes and test incrementally
3. **Document Issues**: Note what works and what doesn't in LocalStack
4. **Transition to AWS**: Once validated locally, test in real AWS environment

## Resources

- [LocalStack EKS Documentation](https://docs.localstack.cloud/user-guide/aws/eks/)
- [LocalStack Pro Features](https://localstack.cloud/pricing/)
- [Terraform AWS EKS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)

## Important Reminder

🔴 **This is for learning and testing Terraform syntax only**

LocalStack EKS does not:
- Run actual Kubernetes workloads
- Provide a real Kubernetes API
- Support kubectl operations on pods/deployments
- Replace real EKS testing

Always validate your configuration in a real AWS environment before production use.
