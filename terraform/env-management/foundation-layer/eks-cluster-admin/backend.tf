# =============================================================================
# Backend Configuration
# This workspace is CLI-driven in Terraform Cloud per ADR-014
# =============================================================================

terraform {
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "management-foundation-eks-cluster-admin"
    }
  }
}
