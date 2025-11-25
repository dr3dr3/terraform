terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configure your backend here - example for Terraform Cloud
  # backend "remote" {
  #   organization = "your-org-name"
  #   workspaces {
  #     name = "management-foundation-iam-people"
  #   }
  # }

  # Or for S3 backend:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "management/foundation/iam-roles-for-people/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "management"
      Layer       = "foundation"
      Component   = "iam-people"
    }
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}
