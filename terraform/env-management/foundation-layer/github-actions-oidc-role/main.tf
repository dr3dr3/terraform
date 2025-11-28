terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Project     = "terraform-infrastructure"
      Environment = "management"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # GitHub Actions OIDC provider details (per ADR-013)
  github_oidc_url      = "https://token.actions.githubusercontent.com"
  github_oidc_audience = "sts.amazonaws.com"
  # GitHub's OIDC thumbprint - using the well-known value
  github_oidc_thumbprint = "ffffffffffffffffffffffffffffffffffffffff"
}

# =============================================================================
# GitHub Actions OIDC Provider
# Per ADR-013: Create OIDC provider for GitHub Actions authentication
# =============================================================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = local.github_oidc_url
  client_id_list  = [local.github_oidc_audience]
  thumbprint_list = [local.github_oidc_thumbprint]

  tags = {
    Name    = "github-actions-oidc-provider"
    Purpose = "GitHub Actions OIDC authentication for EKS provisioning"
  }
}

# =============================================================================
# GitHub Actions IAM Role for Development Platform Layer
# Per ADR-013: Role name is "github-actions-dev-platform"
# =============================================================================
resource "aws_iam_role" "github_actions_dev_platform" {
  name        = "github-actions-dev-platform"
  description = "GitHub Actions role for provisioning EKS in development platform layer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Audience condition per ADR-013
            "token.actions.githubusercontent.com:aud" = local.github_oidc_audience
          }
          StringLike = {
            # Subject condition per ADR-013: scope to specific repo
            # Using StringLike to allow wildcard matching for branches/refs
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  max_session_duration  = var.session_duration
  force_detach_policies = true

  tags = {
    Name        = "github-actions-dev-platform"
    Environment = "development"
    Layer       = "platform"
    Purpose     = "EKS provisioning via GitHub Actions"
  }
}

# =============================================================================
# Attach the custom policy for EKS provisioning
# =============================================================================
resource "aws_iam_role_policy" "github_actions_dev_platform_permissions" {
  name   = "github-actions-dev-platform-policy"
  role   = aws_iam_role.github_actions_dev_platform.id
  policy = data.aws_iam_policy_document.github_actions_dev_platform_permissions.json
}
