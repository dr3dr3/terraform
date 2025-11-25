# Terraform Cloud Projects for organizing workspaces
# Based on ADR-009 folder structure

# Management Account Project
# Contains IAM, identity, and cross-account resources
# Used for managing Terraform Cloud itself (here, created manually to avoid circular dependency)

# Development Environment Project
# Contains all development environment workspaces
resource "tfe_project" "aws_development" {
  organization = data.tfe_organization.main.name
  name         = "aws-development"
  description  = "Development environment infrastructure - EKS clusters, applications, and supporting services"
}

# Staging Environment Project
# Contains all staging environment workspaces
resource "tfe_project" "aws_staging" {
  organization = data.tfe_organization.main.name
  name         = "aws-staging"
  description  = "Staging environment infrastructure - EKS clusters, applications, and supporting services"
}

# Production Environment Project
# Contains all production environment workspaces
resource "tfe_project" "aws_production" {
  organization = data.tfe_organization.main.name
  name         = "aws-production"
  description  = "Production environment infrastructure - EKS clusters, applications, and supporting services"
}

# Sandbox Environment Project
# Contains experimental and learning workspaces
resource "tfe_project" "aws_sandbox" {
  organization = data.tfe_organization.main.name
  name         = "aws-sandbox"
  description  = "Sandbox environment for experiments and learning - auto-cleanup enabled"
}

