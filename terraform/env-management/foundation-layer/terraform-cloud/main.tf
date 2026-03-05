data "tfe_organization" "main" {
  name = var.tfc_organization
}

locals {
  # ---------------------------------------------------------------------------
  # AWS Account IDs
  # ---------------------------------------------------------------------------
  # These are centralised here as the single source of truth for account IDs
  # in this workspace. They CANNOT be read via tfe_outputs because this
  # terraform-cloud workspace creates the workspaces that produce those outputs
  # — using tfe_outputs would create a circular dependency.
  #
  # If an account ID changes, update it here once and all variable values
  # will update on the next apply of this workspace.
  # ---------------------------------------------------------------------------
  account_id_management  = "169506999567"
  account_id_development = "126350206316"
  account_id_staging     = "163436765579"
  account_id_production  = "820485071161"
  account_id_sandbox     = "898468025925"

  # ---------------------------------------------------------------------------
  # TFC OIDC Role ARNs (per environment)
  # ---------------------------------------------------------------------------
  # The management OIDC role is used by all management-account workspaces.
  # Per-environment foundation CICD roles are used by their respective
  # foundation-layer workspaces.
  #
  # Why not tfe_outputs? See account ID note above — same circular dependency.
  # These are bootstrap values: the terraform-cloud workspace creates the other
  # workspaces, which in turn create these roles. The roles therefore pre-exist
  # and are known values at workspace creation time.
  # ---------------------------------------------------------------------------
  tfc_oidc_role_arn_management = "arn:aws:iam::${local.account_id_management}:role/terraform-cloud-oidc-role"
  tfc_cicd_role_arn_dev        = "arn:aws:iam::${local.account_id_development}:role/terraform-dev-foundation-cicd-role"
  tfc_cicd_role_arn_staging    = "arn:aws:iam::${local.account_id_staging}:role/terraform-stg-foundation-cicd-role"
  tfc_cicd_role_arn_production = "arn:aws:iam::${local.account_id_production}:role/terraform-prod-foundation-cicd-role"

  tfc_cicd_role_arn_dev_applications  = "arn:aws:iam::${local.account_id_development}:role/terraform-dev-applications-cicd-role"
  tfc_cicd_role_arn_prod_applications = "arn:aws:iam::${local.account_id_production}:role/terraform-prod-applications-cicd-role"

  # ---------------------------------------------------------------------------
  # Account ID lists (for IAM Roles for People workspace variables)
  # ---------------------------------------------------------------------------
  # All accounts get Admin, Platform Engineers, and Auditors access
  all_account_ids = [
    local.account_id_development,
    local.account_id_staging,
    local.account_id_production,
    local.account_id_sandbox,
  ]

  # Non-production accounts for Namespace Admins and Developers
  # Developers should not have access to Production
  non_production_account_ids = [
    local.account_id_development,
    local.account_id_staging,
    local.account_id_sandbox,
  ]

  # GitHub repository details
  vcs_repo = {
    identifier     = var.github_repository_identifier
    oauth_token_id = var.github_oauth_token_id
    branch         = var.vcs_branch
  }
}
