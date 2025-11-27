terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  # Terraform Cloud backend configuration
  cloud {
    organization = "Datafaced" # Replace with your Terraform Cloud organization name

    workspaces {
      name = "management-foundation-iam-roles-for-terraform"
    }
  }
}

# AWS Provider configuration
# Uses dynamic credentials from Terraform Cloud OIDC
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "management"
      Layer       = "foundation"
      ManagedBy   = "Terraform"
      Workspace   = "management-foundation-iam-roles-for-terraform"
    }
  }
}
