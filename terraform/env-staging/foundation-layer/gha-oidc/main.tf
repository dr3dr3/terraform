# =============================================================================
# GitHub Actions OIDC Provider and IAM Role - Staging Account
# =============================================================================
# Per ADR-013: Create OIDC provider and IAM role in the staging AWS account
# to allow GitHub Actions to assume a role for EKS provisioning.
#
# This must be deployed to the staging AWS account (not management account)
# because the OIDC provider must exist in the same account where GitHub Actions
# will be assuming the role.
# =============================================================================

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
      Environment = "Staging"
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
# Note: Only ONE OIDC provider per identity provider URL per account is allowed
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
# GitHub Actions IAM Role for Staging Platform Layer
# Per ADR-013: Role name is "github-actions-stg-platform"
# =============================================================================
resource "aws_iam_role" "github_actions_stg_platform" {
  name        = "github-actions-stg-platform"
  description = "GitHub Actions role for provisioning EKS in staging platform layer"

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
    Name        = "github-actions-stg-platform"
    Environment = "Staging"
    Layer       = "platform"
    Purpose     = "EKS provisioning via GitHub Actions"
  }
}

# =============================================================================
# Attach the custom policy for EKS provisioning
# =============================================================================
resource "aws_iam_role_policy" "github_actions_stg_platform_permissions" {
  name   = "github-actions-stg-platform-policy"
  role   = aws_iam_role.github_actions_stg_platform.id
  policy = data.aws_iam_policy_document.github_actions_stg_platform_permissions.json
}
