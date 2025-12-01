# =============================================================================
# Backend Configuration - Development Account GitHub Actions OIDC Role
# =============================================================================
# IMPORTANT: This workspace needs to be bootstrapped manually or via CLI
# because it creates the OIDC provider that enables GitHub Actions to work.
#
# Initial deployment options:
# 1. Run locally with AWS credentials for the development account
# 2. Use Terraform Cloud with a workspace configured for the dev account
# =============================================================================

terraform {
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "development-foundation-gha-oidc"
    }
  }
}
