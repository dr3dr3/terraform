terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.19.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Sandbox"
      ManagedBy   = "Terraform"
      Purpose     = "IAM-Roles-PermissionSets"
    }
  }
}

locals {
  environment = "sandbox"
}

# Permission Sets for IAM Identity Center
module "test_permission_set" {
  source = "../../"

  permission_set_name = "Sandbox-Test"
  description         = "Sandbox TEST permission set"
  environment         = local.environment
  layer               = "test" # foundation / platform / application / test
  session_duration    = "PT12H" # 12 hours

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  # This example inline policy provides full S3 access
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FoundationNetworking"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })

  account_assignments = var.sandbox_account_assignments

  tags = var.tags
}

