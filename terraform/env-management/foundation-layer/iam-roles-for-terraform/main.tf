data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Terraform Cloud OIDC provider details
  tfc_hostname = "app.terraform.io"
  tfc_audience = "aws.workload.identity"

  # Common tags for all resources
  common_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = "terraform-infrastructure"
  }
}

# First, create the OIDC provider for Terraform Cloud
resource "aws_iam_openid_connect_provider" "terraform_cloud" {
  url = "https://${local.tfc_hostname}"

  client_id_list = [
    local.tfc_audience,
  ]

  # Thumbprint for app.terraform.io
  # This is the TLS certificate thumbprint for Terraform Cloud
  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280", # Current TFC thumbprint
  ]

  tags = merge(
    local.common_tags,
    {
      Name      = "terraform-cloud-oidc-provider"
      Purpose   = "OIDC authentication for Terraform Cloud"
      ManagedBy = "Terraform"
    }
  )
}

# Development Environment Roles
module "dev_foundation_cicd_role" {
  source = "../../../terraform-modules/terraform-oidc-role"

  role_name          = "terraform-dev-foundation-cicd-role"
  environment        = "dev"
  layer              = "foundation"
  context            = "cicd"
  oidc_provider_arn  = aws_iam_openid_connect_provider.terraform_cloud.arn
  oidc_provider_url  = local.tfc_hostname
  oidc_audience      = local.tfc_audience
  cicd_subject_claim = "organization:${var.tfc_organization}:project:${var.tfc_project_dev}:workspace:${var.tfc_workspace_dev_foundation}:run_phase:*"
  session_duration   = 7200 # 2 hours

  attach_readonly_policy = true
  custom_policy_json     = data.aws_iam_policy_document.dev_foundation_permissions.json

  tags = local.common_tags
}

# Staging Environment Roles
module "staging_foundation_cicd_role" {
  source = "../../../terraform-modules/terraform-oidc-role"

  role_name          = "terraform-staging-foundation-cicd-role"
  environment        = "staging"
  layer              = "foundation"
  context            = "cicd"
  oidc_provider_arn  = aws_iam_openid_connect_provider.terraform_cloud.arn
  oidc_provider_url  = local.tfc_hostname
  oidc_audience      = local.tfc_audience
  cicd_subject_claim = "organization:${var.tfc_organization}:project:${var.tfc_project_staging}:workspace:${var.tfc_workspace_staging_foundation}:run_phase:*"
  session_duration   = 3600 # 1 hour

  attach_readonly_policy = true
  custom_policy_json     = data.aws_iam_policy_document.staging_foundation_permissions.json

  tags = local.common_tags
}

# Production Environment Roles
module "prod_foundation_cicd_role" {
  source = "../../../terraform-modules/terraform-oidc-role"

  role_name          = "terraform-production-foundation-cicd-role"
  environment        = "production"
  layer              = "foundation"
  context            = "cicd"
  oidc_provider_arn  = aws_iam_openid_connect_provider.terraform_cloud.arn
  oidc_provider_url  = local.tfc_hostname
  oidc_audience      = local.tfc_audience
  cicd_subject_claim = "organization:${var.tfc_organization}:project:${var.tfc_project_prod}:workspace:${var.tfc_workspace_prod_foundation}:run_phase:*"
  session_duration   = 3600 # 1 hour

  attach_readonly_policy = true
  custom_policy_json     = data.aws_iam_policy_document.prod_foundation_permissions.json

  tags = local.common_tags
}
