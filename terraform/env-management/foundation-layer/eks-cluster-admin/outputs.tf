# =============================================================================
# Outputs - EKS 1Password Sync
# =============================================================================

output "synced_clusters" {
  description = "List of EKS clusters synced to 1Password"
  sensitive   = true
  value = {
    development = var.sync_development_eks ? {
      cluster_name   = local.dev_cluster_name
      onepassword_id = try(onepassword_item.eks_development[0].uuid, null)
    } : null
    staging = var.sync_staging_eks ? {
      cluster_name   = local.staging_cluster_name
      onepassword_id = try(onepassword_item.eks_staging[0].uuid, null)
    } : null
    production = var.sync_production_eks ? {
      cluster_name   = local.prod_cluster_name
      onepassword_id = try(onepassword_item.eks_production[0].uuid, null)
    } : null
    sandbox = var.sync_sandbox_eks ? {
      cluster_name   = local.sandbox_cluster_name
      onepassword_id = try(onepassword_item.eks_sandbox[0].uuid, null)
    } : null
  }
}

output "onepassword_vault" {
  description = "1Password vault used for storing cluster details"
  value       = var.onepassword_vault_name
}

output "development_connect_command" {
  description = "Command to connect to development EKS cluster"
  value       = var.sync_development_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.dev_cluster_name}" : null
  sensitive   = true
}

output "staging_connect_command" {
  description = "Command to connect to staging EKS cluster"
  value       = var.sync_staging_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.staging_cluster_name}" : null
  sensitive   = true
}

output "production_connect_command" {
  description = "Command to connect to production EKS cluster"
  value       = var.sync_production_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.prod_cluster_name}" : null
  sensitive   = true
}

output "sandbox_connect_command" {
  description = "Command to connect to sandbox EKS cluster"
  value       = var.sync_sandbox_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.sandbox_cluster_name}" : null
  sensitive   = true
}
