# =============================================================================
# Outputs - EKS Auto Mode Cluster
# =============================================================================
# These outputs are used by other layers (e.g., applications layer)
# and for configuring kubectl access
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Information
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version of the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster (for IRSA)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider (for IRSA trust policies)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# -----------------------------------------------------------------------------
# VPC Information
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones used by the cluster"
  value       = local.azs
}

# -----------------------------------------------------------------------------
# IAM Information
# -----------------------------------------------------------------------------

output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "auto_node_role_arn" {
  description = "ARN of the EKS Auto Mode node IAM role"
  value       = aws_iam_role.eks_auto_node.arn
}

# -----------------------------------------------------------------------------
# KMS Information
# -----------------------------------------------------------------------------

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used for secrets encryption"
  value       = var.enable_secrets_encryption ? aws_kms_key.eks_secrets[0].arn : null
}

output "secrets_kms_key_id" {
  description = "ID of the KMS key used for secrets encryption"
  value       = var.enable_secrets_encryption ? aws_kms_key.eks_secrets[0].key_id : null
}

# -----------------------------------------------------------------------------
# kubectl Configuration
# -----------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.main.name}"
}

# -----------------------------------------------------------------------------
# CloudWatch Logs
# -----------------------------------------------------------------------------

output "cluster_log_group_name" {
  description = "Name of the CloudWatch log group for control plane logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}
