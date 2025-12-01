terraform {
  required_version = ">= 1.14.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }

  cloud {
    organization = "Datafaced"

    workspaces {
      name = "management-foundation-github-dr3dr3"
    }
  }
}

# GitHub Provider configuration
# Uses a GitHub Personal Access Token (PAT) or GitHub App for authentication
# The token should be provided via the GITHUB_TOKEN environment variable
# or via Terraform Cloud workspace variables
provider "github" {
  owner = var.github_owner

  # Authentication is handled via:
  # - GITHUB_TOKEN environment variable (PAT with repo, admin:org scopes)
  # - Or app_auth block for GitHub App authentication
}
