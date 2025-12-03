data "tfe_organization" "main" {
  name = var.tfc_organization
}

locals {
  # AWS Account IDs for IAM Roles for People workspace
  # All accounts get Admin, Platform Engineers, and Auditors access
  all_account_ids = [
    "126350206316", # Development
    "163436765579", # Staging
    "820485071161", # Production
    "898468025925", # Sandbox
  ]

  # Non-production accounts for Namespace Admins and Developers
  # Developers should not have access to Production
  non_production_account_ids = [
    "126350206316", # Development
    "163436765579", # Staging
    "898468025925", # Sandbox
  ]

  # GitHub repository details
  vcs_repo = {
    identifier     = var.github_repository_identifier
    oauth_token_id = var.github_oauth_token_id
    branch         = var.vcs_branch
  }
}
