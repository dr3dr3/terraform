# =============================================================================
# Backend Configuration
# Per ADR-013: This workspace is GitHub Actions-driven in Terraform Cloud
# =============================================================================

terraform {
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "staging-platform-eks"
    }
  }
}
