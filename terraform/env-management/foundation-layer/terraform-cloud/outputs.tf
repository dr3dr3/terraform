################################################################################
# Project Outputs
################################################################################

output "project_aws_management_id" {
  description = "ID of the AWS Management project"
  value       = tfe_project.aws_management.id
}

output "project_aws_development_id" {
  description = "ID of the AWS Development project"
  value       = tfe_project.aws_development.id
}

output "project_aws_staging_id" {
  description = "ID of the AWS Staging project"
  value       = tfe_project.aws_staging.id
}

output "project_aws_production_id" {
  description = "ID of the AWS Production project"
  value       = tfe_project.aws_production.id
}

output "project_aws_sandbox_id" {
  description = "ID of the AWS Sandbox project"
  value       = tfe_project.aws_sandbox.id
}

################################################################################
# Management Workspace Outputs
################################################################################

output "workspace_management_tfc_oidc_role_id" {
  description = "ID of management-foundation-tfc-oidc-role workspace"
  value       = tfe_workspace.management_foundation_tfc_oidc_role.id
}

output "workspace_management_iam_people_id" {
  description = "ID of management-foundation-iam-roles-for-people workspace"
  value       = tfe_workspace.management_foundation_iam_people.id
}

output "workspace_management_gha_oidc_id" {
  description = "ID of management-github-actions-oidc workspace"
  value       = tfe_workspace.management_foundation_gha_oidc.id
}

################################################################################
# Development Workspace Outputs
################################################################################

output "workspace_dev_foundation_iam_roles_id" {
  description = "ID of development-foundation-iam-roles workspace"
  value       = tfe_workspace.dev_foundation_iam_roles.id
}

output "workspace_dev_foundation_iam_roles_name" {
  description = "Name of development-foundation-iam-roles workspace"
  value       = tfe_workspace.dev_foundation_iam_roles.name
}

output "workspace_dev_platform_eks_id" {
  description = "ID of development-platform-eks workspace"
  value       = tfe_workspace.dev_platform_eks.id
}

output "workspace_dev_platform_eks_name" {
  description = "Name of development-platform-eks workspace"
  value       = tfe_workspace.dev_platform_eks.name
}

output "workspace_dev_foundation_gha_oidc_id" {
  description = "ID of development-foundation-gha-oidc workspace"
  value       = tfe_workspace.dev_foundation_gha_oidc.id
}

output "workspace_dev_foundation_gha_oidc_name" {
  description = "Name of development-foundation-gha-oidc workspace"
  value       = tfe_workspace.dev_foundation_gha_oidc.name
}

################################################################################
# Staging Workspace Outputs
################################################################################

output "workspace_staging_foundation_iam_roles_id" {
  description = "ID of staging-foundation-iam-roles workspace"
  value       = tfe_workspace.staging_foundation_iam_roles.id
}

output "workspace_staging_foundation_iam_roles_name" {
  description = "Name of staging-foundation-iam-roles workspace"
  value       = tfe_workspace.staging_foundation_iam_roles.name
}

################################################################################
# Sandbox Workspace Outputs
################################################################################

output "workspace_sandbox_foundation_iam_roles_id" {
  description = "ID of sandbox-foundation-iam-roles workspace"
  value       = tfe_workspace.sandbox_foundation_iam_roles.id
}

output "workspace_sandbox_foundation_iam_roles_name" {
  description = "Name of sandbox-foundation-iam-roles workspace"
  value       = tfe_workspace.sandbox_foundation_iam_roles.name
}

output "workspace_sandbox_platform_eks_id" {
  description = "ID of sandbox-platform-eks workspace"
  value       = tfe_workspace.sandbox_platform_eks.id
}

output "workspace_sandbox_platform_eks_name" {
  description = "Name of sandbox-platform-eks workspace"
  value       = tfe_workspace.sandbox_platform_eks.name
}

################################################################################
# Summary Outputs
################################################################################

output "workspace_count" {
  description = "Total number of workspaces managed"
  value = length([
    # Management workspaces
    tfe_workspace.management_foundation_tfc_oidc_role.id,
    tfe_workspace.management_foundation_iam_people.id,
    tfe_workspace.management_foundation_gha_oidc.id,
    # Development workspaces
    tfe_workspace.dev_foundation_iam_roles.id,
    tfe_workspace.dev_foundation_gha_oidc.id,
    tfe_workspace.dev_platform_eks.id,
    # Staging workspaces
    tfe_workspace.staging_foundation_iam_roles.id,
    # Sandbox workspaces
    tfe_workspace.sandbox_foundation_iam_roles.id,
    tfe_workspace.sandbox_platform_eks.id,
  ])
}

output "terraform_cloud_url" {
  description = "URL to Terraform Cloud organization"
  value       = "https://app.terraform.io/app/${var.tfc_organization}"
}

################################################################################
# Workspace Trigger Summary (per ADR-014)
################################################################################

output "workspace_trigger_summary" {
  description = "Summary of workspace trigger types per ADR-014"
  value = {
    cli_driven = [
      # All Foundation workspaces use CLI-driven triggers
      tfe_workspace.management_foundation_tfc_oidc_role.name,
      tfe_workspace.management_foundation_iam_people.name,
      tfe_workspace.management_foundation_gha_oidc.name,
      tfe_workspace.dev_foundation_iam_roles.name,
      tfe_workspace.dev_foundation_gha_oidc.name,
      tfe_workspace.staging_foundation_iam_roles.name,
      tfe_workspace.sandbox_foundation_iam_roles.name,
    ]
    vcs_driven = [
      # Platform (sandbox) uses VCS-driven triggers per ADR-014
      tfe_workspace.sandbox_platform_eks.name,
    ]
    api_gha_driven = [
      # Platform (dev) uses API/GHA-driven triggers per ADR-014
      tfe_workspace.dev_platform_eks.name,
    ]
  }
}
