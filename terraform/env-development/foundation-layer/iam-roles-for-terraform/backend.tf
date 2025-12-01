terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  # Terraform Cloud backend configuration
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "development-foundation-iam-roles-for-terraform"
    }
  }
}

# AWS Provider configuration
# Uses dynamic credentials from Terraform Cloud OIDC
# NOTE: This workspace runs in the DEVELOPMENT account (126350206316)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Development"
      Layer       = "Foundation"
      ManagedBy   = "Terraform"
      Workspace   = "development-foundation-iam-roles"
    }
  }
}
