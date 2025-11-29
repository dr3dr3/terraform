################################################################################
# Management Environment Workspaces
################################################################################

# Management - Foundation Layer - Terraform Cloud OIDC Role
resource "tfe_workspace" "management_foundation_tfc_oidc_role" {
  name         = "management-foundation-tfc-oidc-role"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "OIDC provider and Terraform Cloud"

  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_management

  tag_names = [
    "environment:management",
    "layer:foundation",
    "aws-account:management"
  ]
}

# Note: OIDC variables for tfc-oidc-role workspace were created manually
# and are not managed via Terraform to avoid chicken-and-egg bootstrap issues

# Management - Foundation Layer - IAM Roles for People
resource "tfe_workspace" "management_foundation_iam_people" {
  name         = "management-foundation-iam-roles-for-people"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "IAM Identity Center groups, permission sets, and account assignments"

  vcs_repo {
    identifier     = local.vcs_repo.identifier
    oauth_token_id = local.vcs_repo.oauth_token_id
    branch         = local.vcs_repo.branch
  }

  working_directory = "terraform/env-management/foundation-layer/iam-roles-for-people"
  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_management

  tag_names = [
    "environment:management",
    "layer:foundation",
    "aws-account:management"
  ]
}

# Environment variables for OIDC authentication - IAM Roles for People
resource "tfe_variable" "management_foundation_iam_people_auth" {
  workspace_id = tfe_workspace.management_foundation_iam_people.id
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
  category     = "env"
  description  = "Enable AWS provider authentication via OIDC"
}

resource "tfe_variable" "management_foundation_iam_people_role_arn" {
  workspace_id = tfe_workspace.management_foundation_iam_people.id
  key          = "TFC_AWS_RUN_ROLE_ARN"
  value        = "arn:aws:iam::169506999567:role/terraform-cloud-oidc-role"
  category     = "env"
  description  = "AWS IAM role ARN for OIDC authentication"
}

# Management - Foundation Layer - IAM Roles for Terraform (OIDC)
resource "tfe_workspace" "management_foundation_iam_terraform" {
  name         = "management-foundation-iam-roles-for-terraform"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "OIDC provider and IAM roles for Terraform Cloud workspaces"

  vcs_repo {
    identifier     = local.vcs_repo.identifier
    oauth_token_id = local.vcs_repo.oauth_token_id
    branch         = local.vcs_repo.branch
  }

  working_directory = "terraform/env-management/foundation-layer/iam-roles-for-terraform"
  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_management

  tag_names = [
    "environment:management",
    "layer:foundation",
    "aws-account:management"
  ]
}

# Environment variables for OIDC authentication - IAM Roles for Terraform
resource "tfe_variable" "management_foundation_iam_terraform_auth" {
  workspace_id = tfe_workspace.management_foundation_iam_terraform.id
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
  category     = "env"
  description  = "Enable AWS provider authentication via OIDC"
}

resource "tfe_variable" "management_foundation_iam_terraform_role_arn" {
  workspace_id = tfe_workspace.management_foundation_iam_terraform.id
  key          = "TFC_AWS_RUN_ROLE_ARN"
  value        = "arn:aws:iam::169506999567:role/terraform-cloud-oidc-role"
  category     = "env"
  description  = "AWS IAM role ARN for OIDC authentication"
}

# Management - Foundation Layer - GitHub Actions OIDC Role
# Creates OIDC provider and IAM role for GitHub Actions to provision EKS (ADR-013)
resource "tfe_workspace" "management_foundation_gha_oidc" {
  name         = "management-github-actions-oidc"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "GitHub Actions OIDC provider and IAM role for EKS provisioning"

  vcs_repo {
    identifier     = local.vcs_repo.identifier
    oauth_token_id = local.vcs_repo.oauth_token_id
    branch         = local.vcs_repo.branch
  }

  working_directory = "terraform/env-management/foundation-layer/github-actions-oidc-role"
  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_management

  tag_names = [
    "environment:management",
    "layer:foundation",
    "aws-account:management",
    "cicd:github-actions"
  ]
}

# Environment variables for OIDC authentication - GitHub Actions OIDC Role
resource "tfe_variable" "management_foundation_gha_oidc_auth" {
  workspace_id = tfe_workspace.management_foundation_gha_oidc.id
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
  category     = "env"
  description  = "Enable AWS provider authentication via OIDC"
}

resource "tfe_variable" "management_foundation_gha_oidc_role_arn" {
  workspace_id = tfe_workspace.management_foundation_gha_oidc.id
  key          = "TFC_AWS_RUN_ROLE_ARN"
  value        = "arn:aws:iam::169506999567:role/terraform-cloud-oidc-role"
  category     = "env"
  description  = "AWS IAM role ARN for OIDC authentication"
}

################################################################################
# Development Environment Workspaces
################################################################################

# Development - Platform Layer - EKS Auto Mode Cluster
# This workspace is GitHub Actions-driven (not VCS-driven)
# Per ADR-013: Uses OIDC federation with GitHub Actions for authentication
resource "tfe_workspace" "dev_platform_eks" {
  name         = "development-platform-eks"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_development.id
  description  = "EKS Auto Mode cluster for development environment"

  # No VCS repo - triggered by GitHub Actions workflow
  # vcs_repo block intentionally omitted

  working_directory = "terraform/env-development/platform-layer/eks-auto-mode"
  terraform_version = "~> 1.14.0"
  auto_apply        = false  # GitHub Actions workflow controls apply

  # Allow runs to be triggered externally (by GitHub Actions)
  queue_all_runs = false

  tag_names = [
    "environment:development",
    "layer:platform",
    "aws-account:development",
    "cicd:github-actions",
    "workload:eks"
  ]
}

# Note: This workspace does NOT use TFC OIDC for AWS authentication
# Instead, GitHub Actions assumes the IAM role and passes credentials

# # Management - Foundation Layer - Terraform Cloud Management (This workspace!)
# resource "tfe_workspace" "management_foundation_terraform_cloud" {
#   name         = "management-foundation-terraform-cloud"
#   organization = data.tfe_organization.main.name
#   project_id   = tfe_project.aws_management.id
#   description  = "Terraform Cloud projects, workspaces, and configuration management"

#   vcs_repo {
#     identifier     = local.vcs_repo.identifier
#     oauth_token_id = local.vcs_repo.oauth_token_id
#     branch         = local.vcs_repo.branch
#   }

#   working_directory = "terraform/env-management/foundation-layer/terraform-cloud"
#   terraform_version = "~> 1.14.0"
#   auto_apply        = false # Always require manual approval for meta-terraform

#   tag_names = [
#     "environment:management",
#     "layer:foundation",
#     "meta-terraform"
#   ]
# }
