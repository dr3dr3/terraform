# =============================================================================
# Backend Configuration
# This workspace is VCS-driven in Terraform Cloud per ADR-013
# =============================================================================

terraform {
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "management-github-actions-oidc"
    }
  }
}
