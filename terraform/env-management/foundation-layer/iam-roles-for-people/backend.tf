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
      name = "management-foundation-iam-roles-for-people"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy    = "Terraform"
      Environment   = "Management"
      Layer         = "Foundation"
      Component     = "IAM-People"
    }
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

