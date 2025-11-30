################################################################################
# Management Environment Workspaces
################################################################################
#
# Per ADR-014: All Foundation workspaces use CLI-driven trigger (no VCS repo)
# This provides maximum control for high-impact infrastructure changes.
#
################################################################################

# Management - Foundation Layer - Terraform Cloud OIDC Role
# ADR-014: CLI-driven, Manual apply
resource "tfe_workspace" "management_foundation_tfc_oidc_role" {
  name         = "management-foundation-tfc-oidc-role"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "OIDC provider and Terraform Cloud"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "management"
    layer        = "foundation"
    aws-account  = "management"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
  }
}

# Note: OIDC variables for tfc-oidc-role workspace were created manually
# and are not managed via Terraform to avoid chicken-and-egg bootstrap issues

# Management - Foundation Layer - IAM Roles for People
# ADR-014: CLI-driven, Manual apply
resource "tfe_workspace" "management_foundation_iam_people" {
  name         = "management-foundation-iam-roles-for-people"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "IAM Identity Center groups, permission sets, and account assignments"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-management/foundation-layer/iam-roles-for-people"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "management"
    layer        = "foundation"
    aws-account  = "management"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
  }
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

# REMOVED: management_foundation_iam_terraform
# IAM roles for Terraform should be created in each target account, not management.
# See: terraform/env-development/foundation-layer/iam-roles-for-terraform/

# Management - Foundation Layer - GitHub Actions OIDC Role
# ADR-014: CLI-driven, Manual apply (Foundation layer = CLI)
# Creates OIDC provider and IAM role for GitHub Actions
resource "tfe_workspace" "management_foundation_gha_oidc" {
  name         = "management-github-actions-oidc"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_management.id
  description  = "GitHub Actions OIDC provider and IAM role for management account - foundation layer"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-management/foundation-layer/github-actions-oidc-role"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "management"
    layer        = "foundation"
    aws-account  = "management"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
  }
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
#
# Per ADR-014:
# - Foundation: CLI-driven, Manual apply
# - Platform (dev): API/GHA-driven, Auto-apply (with scheduled destroys)
# - Application (dev): API/GHA-driven, Auto-apply
#
################################################################################

# Development - Platform Layer - EKS Auto Mode Cluster
# ADR-014: API/GHA-driven, Auto-apply (enables scheduled create/destroy for cost optimisation)
resource "tfe_workspace" "dev_platform_eks" {
  name         = "development-platform-eks"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_development.id
  description  = "EKS Auto Mode cluster for development environment"

  # API/GHA-driven: No VCS repo - triggered by GitHub Actions workflow
  # Enables scheduled destroys for cost optimisation (see ADR-014)
  # vcs_repo block intentionally omitted

  working_directory = "terraform/env-development/platform-layer/eks-auto-mode"
  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_dev # Auto-apply for fast iteration

  # Allow runs to be triggered externally (by GitHub Actions)
  queue_all_runs = false

  tags = {
    environment  = "development"
    layer        = "platform"
    aws-account  = "development"
    managed-by   = "terraform"
    cicd         = "github-actions" # ADR-014: API/GHA-driven trigger
    workload     = "eks"
  }
}

# Note: This workspace does NOT use TFC OIDC for AWS authentication
# Instead, GitHub Actions assumes the IAM role and passes credentials

# Development - Foundation Layer - GitHub Actions OIDC Role
# ADR-014: CLI-driven, Manual apply (Foundation layer = CLI)
# IMPORTANT: This workspace needs to be bootstrapped with development account credentials
# because it creates the OIDC provider that enables GitHub Actions to work.
resource "tfe_workspace" "dev_foundation_gha_oidc" {
  name         = "development-foundation-gha-oidc"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_development.id
  description  = "GitHub Actions OIDC provider and IAM role for development account"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-development/foundation-layer/github-actions-oidc-role"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "development"
    layer        = "foundation"
    aws-account  = "development"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
    bootstrap    = "true"
  }
}

# NOTE: OIDC variables for dev_foundation_gha_oidc workspace require a role
# in the DEVELOPMENT AWS account. This is a bootstrap step that needs to be
# configured manually in Terraform Cloud with development account credentials.
# Options:
# 1. Use AWS access keys for the development account (temporary, for bootstrap)
# 2. Create a cross-account role from management to development
# 3. Run locally with development account credentials first

# Development - Foundation Layer - IAM Roles for Terraform
# ADR-014: CLI-driven, Manual apply (Foundation layer = CLI)
# Creates OIDC provider and layer-specific IAM roles in the development account
# IMPORTANT: Bootstrap step - requires initial dev account credentials
resource "tfe_workspace" "dev_foundation_iam_roles" {
  name         = "development-foundation-iam-roles"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_development.id
  description  = "OIDC provider and IAM roles for Terraform Cloud in development account"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-development/foundation-layer/iam-roles-for-terraform"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "development"
    layer        = "foundation"
    aws-account  = "development"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
    bootstrap    = "true"
  }
}

# NOTE: OIDC variables for dev_foundation_iam_roles require bootstrapping.
# After initial apply, configure:
#   TFC_AWS_PROVIDER_AUTH = "true"
#   TFC_AWS_RUN_ROLE_ARN  = "arn:aws:iam::126350206316:role/terraform-dev-foundation-cicd-role"

################################################################################
# Staging Environment Workspaces
################################################################################
#
# Per ADR-014:
# - Foundation: CLI-driven, Manual apply
# - Application: VCS-driven, Manual apply (speculative plans on PRs)
# - Platform: API/GHA-driven, Manual apply
#
################################################################################

# Staging - Foundation Layer - IAM Roles for Terraform
# ADR-014: CLI-driven, Manual apply
resource "tfe_workspace" "staging_foundation_iam_roles" {
  name         = "staging-foundation-iam-roles"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_staging.id
  description  = "OIDC provider and IAM roles for Terraform Cloud in staging account"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-staging/foundation-layer/iam-roles-for-terraform"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "staging"
    layer        = "foundation"
    aws-account  = "staging"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
  }
}

################################################################################
# Sandbox Environment Workspaces
################################################################################
#
# Per ADR-014:
# - Foundation: CLI-driven, Manual apply
# - Platform: VCS-driven, Auto-apply (for experimentation)
# - Experiments: VCS-driven, Auto-apply
#
################################################################################

# Sandbox - Foundation Layer - IAM Roles for Terraform
# ADR-014: CLI-driven, Manual apply
resource "tfe_workspace" "sandbox_foundation_iam_roles" {
  name         = "sandbox-foundation-iam-roles"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_sandbox.id
  description  = "OIDC provider and IAM roles for Terraform Cloud in sandbox account"

  # CLI-driven: No VCS repo - operators explicitly initiate changes
  # vcs_repo block intentionally omitted per ADR-014

  working_directory = "terraform/env-sandbox/foundation-layer/iam-roles-for-terraform"
  terraform_version = "~> 1.14.0"
  auto_apply        = false # Foundation requires manual approval

  tags = {
    environment  = "sandbox"
    layer        = "foundation"
    aws-account  = "sandbox"
    managed-by   = "terraform"
    cicd         = "cli" # ADR-014: CLI-driven trigger
  }
}

# Sandbox - Platform Layer - EKS Learning Cluster
# ADR-014: VCS-driven, Auto-apply (for experimentation)
resource "tfe_workspace" "sandbox_platform_eks" {
  name         = "sandbox-platform-eks"
  organization = data.tfe_organization.main.name
  project_id   = tfe_project.aws_sandbox.id
  description  = "EKS Auto Mode cluster for sandbox experimentation"

  # VCS-driven: Automatic speculative plans on PRs, auto-apply on merge
  vcs_repo {
    identifier     = local.vcs_repo.identifier
    oauth_token_id = local.vcs_repo.oauth_token_id
    branch         = local.vcs_repo.branch
  }

  # Trigger only on changes to sandbox platform layer
  trigger_prefixes = ["terraform/env-sandbox/platform-layer/eks-auto-mode"]

  working_directory = "terraform/env-sandbox/platform-layer/eks-auto-mode"
  terraform_version = "~> 1.14.0"
  auto_apply        = var.auto_apply_sandbox # Auto-apply for fast experimentation

  tags = {
    environment  = "sandbox"
    layer        = "platform"
    aws-account  = "sandbox"
    managed-by   = "terraform"
    cicd         = "vcs" # ADR-014: VCS-driven trigger
    workload     = "eks"
  }
}

# # Management - Foundation Layer - Terraform Cloud Management (This workspace!
# resource "tfe_workspace" "management_foundation_terraform_cloud" {
#   name         = "management-foundation-terraform-cloud"
#   organization = data.tfe_organization.main.name
#   project_id   = tfe_project.aws_management.id
#   description  = "Terraform Cloud projects, workspaces, and configuration management"
#
#   # CLI-driven: No VCS repo - meta-terraform requires manual control
#   # vcs_repo block intentionally omitted per ADR-014
#
#   working_directory = "terraform/env-management/foundation-layer/terraform-cloud"
#   terraform_version = "~> 1.14.0"
#   auto_apply        = false # Always require manual approval for meta-terraform
#
#   tags = {
#     environment    = "management"
#     layer          = "foundation"
#     managed-by     = "terraform"
#     cicd           = "cli"
#     meta-terraform = "true"
#   }
# }
