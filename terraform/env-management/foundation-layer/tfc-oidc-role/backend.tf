terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  cloud {
    organization = "Datafaced"

    workspaces {
      name = "management-foundation-tfc-oidc-role"
    }
  }
}

# AWS Provider configuration
# Uses dynamic credentials from Terraform Cloud OIDC
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Management"
    }
  }
}
