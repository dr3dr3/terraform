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

output "project_aws_sandbox_id" {
  description = "ID of the AWS Sandbox project"
  value       = tfe_project.aws_sandbox.id
}

output "project_local_development_id" {
  description = "ID of the Local Development project"
  value       = tfe_project.local_development.id
}

################################################################################
# Management Workspace Outputs
################################################################################

output "workspace_management_iam_people_id" {
  description = "ID of management-foundation-iam-roles-for-people workspace"
  value       = tfe_workspace.management_foundation_iam_people.id
}

output "workspace_management_iam_terraform_id" {
  description = "ID of management-foundation-iam-roles-for-terraform workspace"
  value       = tfe_workspace.management_foundation_iam_terraform.id
}

output "workspace_management_terraform_cloud_id" {
  description = "ID of management-foundation-terraform-cloud workspace (this workspace)"
  value       = tfe_workspace.management_foundation_terraform_cloud.id
}

################################################################################
# Development Workspace Outputs
################################################################################

output "workspace_dev_foundation_iam_id" {
  description = "ID of development-foundation-iam-roles-terraform workspace"
  value       = tfe_workspace.dev_foundation_iam_terraform.id
}

output "workspace_dev_eks_learning_id" {
  description = "ID of development-applications-eks-learning-cluster workspace"
  value       = tfe_workspace.dev_applications_eks_learning.id
}

################################################################################
# Sandbox Workspace Outputs
################################################################################

output "workspace_sandbox_foundation_iam_id" {
  description = "ID of sandbox-foundation-iam-roles-terraform workspace"
  value       = tfe_workspace.sandbox_foundation_iam_terraform.id
}

################################################################################
# Summary Outputs
################################################################################

output "workspace_count" {
  description = "Total number of workspaces managed"
  value = length([
    tfe_workspace.management_foundation_iam_people.id,
    tfe_workspace.management_foundation_iam_terraform.id,
    tfe_workspace.management_foundation_terraform_cloud.id,
    tfe_workspace.dev_foundation_iam_terraform.id,
    tfe_workspace.dev_applications_eks_learning.id,
    tfe_workspace.sandbox_foundation_iam_terraform.id,
  ])
}

output "terraform_cloud_url" {
  description = "URL to Terraform Cloud organization"
  value       = "https://app.terraform.io/app/${var.tfc_organization}"
}
