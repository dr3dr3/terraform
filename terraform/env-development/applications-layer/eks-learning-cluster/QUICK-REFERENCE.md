# EKS Learning Cluster - Quick Reference

## 🚀 Quick Start Commands

### Initial Setup
```bash
# 1. Update Terraform Cloud config in main.tf
# 2. Initialize Terraform
terraform init

# 3. Deploy cluster
terraform apply

# 4. Configure kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name learning-eks

# 5. Verify cluster
kubectl get nodes
```

### Deploy Sample Application
```bash
# Deploy nginx test application
kubectl apply -f sample-app.yaml

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get svc

# Get LoadBalancer URL (wait a few minutes)
kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🔍 Essential kubectl Commands

### Cluster Information
```bash
# Cluster info
kubectl cluster-info

# View nodes
kubectl get nodes -o wide

# Node details
kubectl describe node <node-name>

# Check cluster version
kubectl version

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Working with Pods
```bash
# List all pods
kubectl get pods --all-namespaces

# Describe pod
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow logs

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/sh

# Delete pod
kubectl delete pod <pod-name>
```

### Working with Deployments
```bash
# Create deployment
kubectl create deployment nginx --image=nginx

# List deployments
kubectl get deployments

# Scale deployment
kubectl scale deployment nginx --replicas=3

# Update image
kubectl set image deployment/nginx nginx=nginx:1.27

# Rollout status
kubectl rollout status deployment/nginx

# Rollout history
kubectl rollout history deployment/nginx

# Rollback
kubectl rollout undo deployment/nginx
```

### Working with Services
```bash
# List services
kubectl get svc

# Describe service
kubectl describe svc <service-name>

# Expose deployment
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Delete service
kubectl delete svc <service-name>
```

### Working with Namespaces
```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace dev

# Set default namespace
kubectl config set-context --current --namespace=dev

# Delete namespace
kubectl delete namespace dev
```

### Resource Management
```bash
# Get all resources
kubectl get all -A

# View resource usage
kubectl top nodes
kubectl top pods

# Describe resource quotas
kubectl describe resourcequota

# Get events
kubectl get events --sort-by='.lastTimestamp'
```

## 🔐 IAM and Access Control

### Assume IAM Roles
```bash
# Get role ARNs from Terraform
terraform output eks_admin_role_arn
terraform output eks_readonly_role_arn

# Assume admin role
aws sts assume-role \
  --role-arn <admin-role-arn> \
  --role-session-name eks-admin

# Set credentials from assume-role output
export AWS_ACCESS_KEY_ID=<AccessKeyId>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>
export AWS_SESSION_TOKEN=<SessionToken>

# Verify access
aws sts get-caller-identity
```

### Check Access
```bash
# Test if you can access API
kubectl auth can-i get pods

# Check what you can do
kubectl auth can-i --list

# Test for specific user
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
```

## 🛠️ Troubleshooting Commands

### Node Issues
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node capacity
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# View node logs (requires SSH/Session Manager)
# Check system logs on the node
```

### Pod Issues
```bash
# Check pod status
kubectl get pods -o wide

# Describe pod (see events)
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container

# Check resource usage
kubectl top pod <pod-name>

# Get pod YAML
kubectl get pod <pod-name> -o yaml
```

### Network Issues
```bash
# List services
kubectl get svc -A

# Check endpoints
kubectl get endpoints

# Test connectivity from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
# wget -O- http://service-name
# nslookup service-name
# ping pod-ip

# Check CNI plugin
kubectl get pods -n kube-system | grep aws-node
kubectl logs -n kube-system <aws-node-pod>
```

### Cluster Addons
```bash
# List addons
kubectl get pods -n kube-system

# CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check kube-proxy
kubectl get ds -n kube-system kube-proxy

# VPC CNI
kubectl get ds -n kube-system aws-node
```

## 📊 Monitoring and Logs

### CloudWatch Logs
```bash
# View available log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/learning-eks

# Stream logs
aws logs tail /aws/eks/learning-eks/cluster --follow

# Get specific log stream
aws logs get-log-events \
  --log-group-name /aws/eks/learning-eks/cluster \
  --log-stream-name <stream-name>
```

### Resource Usage
```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods -A

# Sort by CPU
kubectl top pods -A --sort-by=cpu

# Sort by memory
kubectl top pods -A --sort-by=memory
```

## 🧪 Testing and Experimentation

### Create Test Resources
```bash
# Create a test namespace
kubectl create namespace test

# Deploy test pod
kubectl run test-pod --image=nginx -n test

# Create service
kubectl expose pod test-pod --port=80 --type=ClusterIP -n test

# Test from another pod
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -n test -- \
  curl http://test-pod.test.svc.cluster.local
```

### RBAC Testing
```bash
# Create service account
kubectl create serviceaccount my-sa

# Create role
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods

# Create role binding
kubectl create rolebinding my-sa-pod-reader \
  --role=pod-reader \
  --serviceaccount=default:my-sa

# Test as service account
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
```

### Secrets and ConfigMaps
```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret

# Create configmap
kubectl create configmap my-config \
  --from-literal=app.properties=value

# Use in pod
kubectl run test-pod --image=nginx \
  --env="USERNAME=$(kubectl get secret my-secret -o jsonpath='{.data.username}' | base64 -d)"
```

## 💰 Cost Management

### Check Current Resources
```bash
# Count nodes
kubectl get nodes --no-headers | wc -l

# List LoadBalancers (these cost money!)
kubectl get svc -A -o wide | grep LoadBalancer

# List persistent volumes
kubectl get pv

# Check running pods
kubectl get pods -A --field-selector=status.phase=Running
```

### Clean Up Resources
```bash
# Delete test deployments
kubectl delete deployment --all -n test

# Delete services
kubectl delete svc --all -n test

# Delete namespace
kubectl delete namespace test

# Delete LoadBalancers before destroying cluster!
kubectl delete svc -A --field-selector spec.type=LoadBalancer
```

## 🗑️ Cleanup

### Before Destroying Cluster
```bash
# 1. Delete all LoadBalancers
kubectl get svc -A | grep LoadBalancer
kubectl delete svc -A --field-selector spec.type=LoadBalancer

# 2. Delete all PersistentVolumeClaims
kubectl get pvc -A
kubectl delete pvc --all -A

# 3. Wait for resources to be deleted
kubectl get svc -A
kubectl get pvc -A
```

### Destroy Cluster
```bash
# Destroy all Terraform resources
terraform destroy

# Verify in AWS Console:
# - EC2: No remaining instances, volumes, or load balancers
# - VPC: VPC should be deleted
# - EKS: Cluster should be deleted
# - CloudWatch: Log groups (can be deleted manually if needed)
```

## 📚 Useful Resources

### Documentation
- [Kubernetes Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)

### Tools
```bash
# Install k9s (optional terminal UI)
# https://k9scli.io/

# Install kubectx/kubens (context switching)
# https://github.com/ahmetb/kubectx

# Install stern (multi-pod logs)
# https://github.com/stern/stern
```

## ⚡ Pro Tips

1. **Use aliases:**
   ```bash
   alias k=kubectl
   alias kgp='kubectl get pods'
   alias kgs='kubectl get svc'
   alias kgn='kubectl get nodes'
   ```

2. **Use watch for real-time updates:**
   ```bash
   watch kubectl get pods
   ```

3. **Use `--dry-run=client -o yaml` for YAML generation:**
   ```bash
   kubectl create deployment nginx --image=nginx --dry-run=client -o yaml
   ```

4. **Use `-o wide` for more details:**
   ```bash
   kubectl get pods -o wide
   ```

5. **Use `--show-labels` to see labels:**
   ```bash
   kubectl get pods --show-labels
   ```

## 🚨 Important Reminders

- ✅ This cluster is **private only** - you need VPN/bastion or temporary public access
- ✅ **Spot instances** can be interrupted - not for production
- ✅ **Single AZ** - no high availability
- ✅ **Destroy after learning** to avoid costs (~$4/day)
- ✅ **Delete LoadBalancers** before destroying the cluster
- ✅ Monitor AWS costs regularly