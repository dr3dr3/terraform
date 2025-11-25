# Terraform Cloud Projects for organizing workspaces
# Based on ADR-009 folder structure

# Management Account Project
# Contains IAM, identity, and cross-account resources
resource "tfe_project" "aws_management" {
  organization = data.tfe_organization.main.name
  name         = "aws-management"
  description  = "Management account infrastructure - IAM Identity Center, IAM roles, cross-account resources"
}

# Development Environment Project
# Contains all development environment workspaces
resource "tfe_project" "aws_development" {
  organization = data.tfe_organization.main.name
  name         = "aws-development"
  description  = "Development environment infrastructure - EKS clusters, applications, and supporting services"
}

# Sandbox Environment Project
# Contains experimental and learning workspaces
resource "tfe_project" "aws_sandbox" {
  organization = data.tfe_organization.main.name
  name         = "aws-sandbox"
  description  = "Sandbox environment for experiments and learning - auto-cleanup enabled"
}

# Local Development Project (LocalStack)
# Contains local development workspaces using LocalStack
resource "tfe_project" "local_development" {
  organization = data.tfe_organization.main.name
  name         = "local-development"
  description  = "Local development infrastructure using LocalStack - no AWS costs"
}
