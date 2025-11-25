terraform {
  required_version = ">= 1.14.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.52.0"
    }
  }

  # Terraform Cloud backend configuration
  # This workspace manages other Terraform Cloud workspaces
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "management-foundation-terraform-cloud"
    }
  }
}

# Terraform Enterprise/Cloud Provider configuration
# Authentication via TFE_TOKEN environment variable
provider "tfe" {
  # Token should be set via TFE_TOKEN environment variable
  # or configured in ~/.terraform.d/credentials.tfrc.json
}
