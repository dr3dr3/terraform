data "tfe_organization" "main" {
  name = var.tfc_organization
}

locals {
  # Common tags for all resources
  common_tags = {
    owner       = var.owner
    environment  = var.environment
    layer       = var.layer
    managed-by   = var.managed_by
  }

  # GitHub repository details
  vcs_repo = {
    identifier     = var.github_repository_identifier
    oauth_token_id = var.github_oauth_token_id
    branch         = var.vcs_branch
  }
}
