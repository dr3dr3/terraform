# Terraform Cloud Projects for organizing workspaces
# Based on ADR-009 folder structure

# Management Account Project
# Contains IAM, identity, and cross-account resources
resource "tfe_project" "aws_management" {
  organization = data.tfe_organization.main.name
  name         = "aws-management"
  description  = "Contains IAM, identity, and cross-account resources"
}

# Development Environment Project
# Contains all development environment workspaces
resource "tfe_project" "aws_development" {
  organization = data.tfe_organization.main.name
  name         = "aws-development"
  description  = "Contains all development environment workspaces"
}

# Staging Environment Project
# Contains all staging environment workspaces
resource "tfe_project" "aws_staging" {
  organization = data.tfe_organization.main.name
  name         = "aws-staging"
  description  = "Contains all staging environment workspaces"
}

# Production Environment Project
# Contains all production environment workspaces
resource "tfe_project" "aws_production" {
  organization = data.tfe_organization.main.name
  name         = "aws-production"
  description  = "Contains all production environment workspaces"
}

# Sandbox Environment Project
# Contains experimental and learning workspaces
resource "tfe_project" "aws_sandbox" {
  organization = data.tfe_organization.main.name
  name         = "aws-sandbox"
  description  = "Contains experimental and learning workspaces"
}

