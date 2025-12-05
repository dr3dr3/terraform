# =============================================================================
# EKS Cluster Admin - 1Password Sync
# =============================================================================
# This configuration stores EKS cluster connection details in 1Password
# for use by the eks-admin devcontainer repository.
#
# Per ADR-016: Phase 1.2 - Terraform to 1Password Integration
# =============================================================================

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = ">= 2.0.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================
# The 1Password Terraform provider authenticates via Service Account Token.
# The token is passed via the `onepassword_service_account_token` variable.
# =============================================================================

provider "onepassword" {
  service_account_token = var.onepassword_service_account_token
}

# =============================================================================
# Data Sources
# =============================================================================

data "onepassword_vault" "terraform_vault" {
  name = var.onepassword_vault_name
}

# Fetch EKS cluster details from Terraform Cloud state
# This uses tfe_outputs to read outputs from the EKS workspace
data "tfe_outputs" "eks_development" {
  count = var.sync_development_eks ? 1 : 0

  organization = var.tfc_organization
  workspace    = var.eks_development_workspace
}

data "tfe_outputs" "eks_staging" {
  count = var.sync_staging_eks ? 1 : 0

  organization = var.tfc_organization
  workspace    = var.eks_staging_workspace
}

data "tfe_outputs" "eks_production" {
  count = var.sync_production_eks ? 1 : 0

  organization = var.tfc_organization
  workspace    = var.eks_production_workspace
}

data "tfe_outputs" "eks_sandbox" {
  count = var.sync_sandbox_eks ? 1 : 0

  organization = var.tfc_organization
  workspace    = var.eks_sandbox_workspace
}

# =============================================================================
# 1Password Items - EKS Cluster Details
# =============================================================================
# Per ADR-016: Store only non-secret cluster connection details
# - Cluster name, endpoint, region, account ID
# - Do NOT store: Cluster CA, AWS credentials, kubectl tokens
# =============================================================================

# Development EKS Cluster
# Per ADR-017: Only create 1Password item if cluster actually exists
resource "onepassword_item" "eks_development" {
  count = local.dev_cluster_exists ? 1 : 0

  vault    = data.onepassword_vault.terraform_vault.uuid
  category = "secure_note"
  title    = "EKS-development-${local.dev_cluster_name}"

  tags = ["EKS", "Kubernetes", "Development", "Terraform-Managed"]

  note_value = <<-EOT
    EKS Cluster Connection Details
    ==============================
    Environment: Development
    Managed by: Terraform (management-foundation-eks-cluster-admin)
    Last Updated: ${timestamp()}
    
    Quick Connect Command:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${local.dev_cluster_name}
  EOT

  section {
    label = "Cluster Details"

    field {
      label = "cluster_name"
      type  = "STRING"
      value = local.dev_cluster_name
    }

    field {
      label = "cluster_endpoint"
      type  = "STRING"
      value = local.dev_cluster_endpoint
    }

    field {
      label = "cluster_region"
      type  = "STRING"
      value = var.aws_region
    }

    field {
      label = "aws_account_id"
      type  = "STRING"
      value = var.aws_account_id_development
    }

    field {
      label = "cluster_arn"
      type  = "STRING"
      value = local.dev_cluster_arn
    }

    field {
      label = "oidc_provider_url"
      type  = "STRING"
      value = local.dev_oidc_issuer_url
    }
  }

  section {
    label = "Terraform Metadata"

    field {
      label = "terraform_workspace"
      type  = "STRING"
      value = var.eks_development_workspace
    }

    field {
      label = "source_repository"
      type  = "STRING"
      value = "dr3dr3/terraform"
    }
  }

  lifecycle {
    # Ignore timestamp changes to prevent unnecessary updates
    ignore_changes = [note_value]
  }
}

# Staging EKS Cluster
# Per ADR-017: Only create 1Password item if cluster actually exists
resource "onepassword_item" "eks_staging" {
  count = local.staging_cluster_exists ? 1 : 0

  vault    = data.onepassword_vault.terraform_vault.uuid
  category = "secure_note"
  title    = "EKS-staging-${local.staging_cluster_name}"

  tags = ["EKS", "Kubernetes", "Staging", "Terraform-Managed"]

  note_value = <<-EOT
    EKS Cluster Connection Details
    ==============================
    Environment: Staging
    Managed by: Terraform (management-foundation-eks-cluster-admin)
    
    Quick Connect Command:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${local.staging_cluster_name}
  EOT

  section {
    label = "Cluster Details"

    field {
      label = "cluster_name"
      type  = "STRING"
      value = local.staging_cluster_name
    }

    field {
      label = "cluster_endpoint"
      type  = "STRING"
      value = local.staging_cluster_endpoint
    }

    field {
      label = "cluster_region"
      type  = "STRING"
      value = var.aws_region
    }

    field {
      label = "aws_account_id"
      type  = "STRING"
      value = var.aws_account_id_staging
    }

    field {
      label = "cluster_arn"
      type  = "STRING"
      value = local.staging_cluster_arn
    }

    field {
      label = "oidc_provider_url"
      type  = "STRING"
      value = local.staging_oidc_issuer_url
    }
  }

  section {
    label = "Terraform Metadata"

    field {
      label = "terraform_workspace"
      type  = "STRING"
      value = var.eks_staging_workspace
    }

    field {
      label = "source_repository"
      type  = "STRING"
      value = "dr3dr3/terraform"
    }
  }

  lifecycle {
    ignore_changes = [note_value]
  }
}

# Production EKS Cluster
# Per ADR-017: Only create 1Password item if cluster actually exists
resource "onepassword_item" "eks_production" {
  count = local.prod_cluster_exists ? 1 : 0

  vault    = data.onepassword_vault.terraform_vault.uuid
  category = "secure_note"
  title    = "EKS-production-${local.prod_cluster_name}"

  tags = ["EKS", "Kubernetes", "Production", "Terraform-Managed"]

  note_value = <<-EOT
    EKS Cluster Connection Details
    ==============================
    Environment: Production
    Managed by: Terraform (management-foundation-eks-cluster-admin)
    
    Quick Connect Command:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${local.prod_cluster_name}
  EOT

  section {
    label = "Cluster Details"

    field {
      label = "cluster_name"
      type  = "STRING"
      value = local.prod_cluster_name
    }

    field {
      label = "cluster_endpoint"
      type  = "STRING"
      value = local.prod_cluster_endpoint
    }

    field {
      label = "cluster_region"
      type  = "STRING"
      value = var.aws_region
    }

    field {
      label = "aws_account_id"
      type  = "STRING"
      value = var.aws_account_id_production
    }

    field {
      label = "cluster_arn"
      type  = "STRING"
      value = local.prod_cluster_arn
    }

    field {
      label = "oidc_provider_url"
      type  = "STRING"
      value = local.prod_oidc_issuer_url
    }
  }

  section {
    label = "Terraform Metadata"

    field {
      label = "terraform_workspace"
      type  = "STRING"
      value = var.eks_production_workspace
    }

    field {
      label = "source_repository"
      type  = "STRING"
      value = "dr3dr3/terraform"
    }
  }

  lifecycle {
    ignore_changes = [note_value]
  }
}

# Sandbox EKS Cluster
# Per ADR-017: Only create 1Password item if cluster actually exists
resource "onepassword_item" "eks_sandbox" {
  count = local.sandbox_cluster_exists ? 1 : 0

  vault    = data.onepassword_vault.terraform_vault.uuid
  category = "secure_note"
  title    = "EKS-sandbox-${local.sandbox_cluster_name}"

  tags = ["EKS", "Kubernetes", "Sandbox", "Terraform-Managed"]

  note_value = <<-EOT
    EKS Cluster Connection Details
    ==============================
    Environment: Sandbox
    Managed by: Terraform (management-foundation-eks-cluster-admin)
    
    Quick Connect Command:
    aws eks update-kubeconfig --region ${var.aws_region} --name ${local.sandbox_cluster_name}
  EOT

  section {
    label = "Cluster Details"

    field {
      label = "cluster_name"
      type  = "STRING"
      value = local.sandbox_cluster_name
    }

    field {
      label = "cluster_endpoint"
      type  = "STRING"
      value = local.sandbox_cluster_endpoint
    }

    field {
      label = "cluster_region"
      type  = "STRING"
      value = var.aws_region
    }

    field {
      label = "aws_account_id"
      type  = "STRING"
      value = var.aws_account_id_sandbox
    }

    field {
      label = "cluster_arn"
      type  = "STRING"
      value = local.sandbox_cluster_arn
    }

    field {
      label = "oidc_provider_url"
      type  = "STRING"
      value = local.sandbox_oidc_issuer_url
    }
  }

  section {
    label = "Terraform Metadata"

    field {
      label = "terraform_workspace"
      type  = "STRING"
      value = var.eks_sandbox_workspace
    }

    field {
      label = "source_repository"
      type  = "STRING"
      value = "dr3dr3/terraform"
    }
  }

  lifecycle {
    ignore_changes = [note_value]
  }
}
