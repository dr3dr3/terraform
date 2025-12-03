# =============================================================================
# Local Values - EKS 1Password Sync
# =============================================================================
# Extract EKS cluster details from Terraform Cloud state outputs
#
# Per ADR-017: Cluster existence is determined by checking if TFC outputs
# contain valid cluster data. This enables automatic cleanup of 1Password
# items when EKS clusters are destroyed (count becomes 0).
# =============================================================================

locals {
  # ===========================================================================
  # Development EKS Cluster
  # ===========================================================================
  # Check if cluster exists by verifying outputs are non-empty
  dev_cluster_exists = (
    var.sync_development_eks &&
    length(data.tfe_outputs.eks_development) > 0 &&
    try(data.tfe_outputs.eks_development[0].values.cluster_name, "") != ""
  )

  # Extract cluster details (only if cluster exists)
  dev_cluster_name     = local.dev_cluster_exists ? try(data.tfe_outputs.eks_development[0].values.cluster_name, "") : ""
  dev_cluster_endpoint = local.dev_cluster_exists ? try(data.tfe_outputs.eks_development[0].values.cluster_endpoint, "") : ""
  dev_cluster_arn      = local.dev_cluster_exists ? try(data.tfe_outputs.eks_development[0].values.cluster_arn, "") : ""
  dev_oidc_issuer_url  = local.dev_cluster_exists ? try(data.tfe_outputs.eks_development[0].values.cluster_oidc_issuer_url, "") : ""

  # ===========================================================================
  # Staging EKS Cluster
  # ===========================================================================
  staging_cluster_exists = (
    var.sync_staging_eks &&
    length(data.tfe_outputs.eks_staging) > 0 &&
    try(data.tfe_outputs.eks_staging[0].values.cluster_name, "") != ""
  )

  staging_cluster_name     = local.staging_cluster_exists ? try(data.tfe_outputs.eks_staging[0].values.cluster_name, "") : ""
  staging_cluster_endpoint = local.staging_cluster_exists ? try(data.tfe_outputs.eks_staging[0].values.cluster_endpoint, "") : ""
  staging_cluster_arn      = local.staging_cluster_exists ? try(data.tfe_outputs.eks_staging[0].values.cluster_arn, "") : ""
  staging_oidc_issuer_url  = local.staging_cluster_exists ? try(data.tfe_outputs.eks_staging[0].values.cluster_oidc_issuer_url, "") : ""

  # ===========================================================================
  # Production EKS Cluster
  # ===========================================================================
  prod_cluster_exists = (
    var.sync_production_eks &&
    length(data.tfe_outputs.eks_production) > 0 &&
    try(data.tfe_outputs.eks_production[0].values.cluster_name, "") != ""
  )

  prod_cluster_name     = local.prod_cluster_exists ? try(data.tfe_outputs.eks_production[0].values.cluster_name, "") : ""
  prod_cluster_endpoint = local.prod_cluster_exists ? try(data.tfe_outputs.eks_production[0].values.cluster_endpoint, "") : ""
  prod_cluster_arn      = local.prod_cluster_exists ? try(data.tfe_outputs.eks_production[0].values.cluster_arn, "") : ""
  prod_oidc_issuer_url  = local.prod_cluster_exists ? try(data.tfe_outputs.eks_production[0].values.cluster_oidc_issuer_url, "") : ""

  # ===========================================================================
  # Sandbox EKS Cluster
  # ===========================================================================
  sandbox_cluster_exists = (
    var.sync_sandbox_eks &&
    length(data.tfe_outputs.eks_sandbox) > 0 &&
    try(data.tfe_outputs.eks_sandbox[0].values.cluster_name, "") != ""
  )

  sandbox_cluster_name     = local.sandbox_cluster_exists ? try(data.tfe_outputs.eks_sandbox[0].values.cluster_name, "") : ""
  sandbox_cluster_endpoint = local.sandbox_cluster_exists ? try(data.tfe_outputs.eks_sandbox[0].values.cluster_endpoint, "") : ""
  sandbox_cluster_arn      = local.sandbox_cluster_exists ? try(data.tfe_outputs.eks_sandbox[0].values.cluster_arn, "") : ""
  sandbox_oidc_issuer_url  = local.sandbox_cluster_exists ? try(data.tfe_outputs.eks_sandbox[0].values.cluster_oidc_issuer_url, "") : ""
}
