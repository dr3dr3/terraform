terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# IAM Role for OIDC authentication
resource "aws_iam_role" "terraform" {
  name        = var.role_name
  description = "Terraform ${var.context} role for ${var.environment} ${var.layer} layer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          {
            StringEquals = {
              "${var.oidc_provider_url}:aud" = var.oidc_audience
            }
          },
          var.context == "cicd" ? {
            StringEquals = {
              "${var.oidc_provider_url}:sub" = var.cicd_subject_claim
            }
          } : {
            StringLike = {
              "${var.oidc_provider_url}:sub" = var.human_subject_pattern
            }
          }
        )
      }
    ]
  })

  max_session_duration  = var.session_duration
  permissions_boundary  = var.permission_boundary_arn
  force_detach_policies = true

  tags = merge(
    var.tags,
    {
      Name        = var.role_name
      Environment = var.environment
      Layer       = var.layer
      Context     = var.context
      ManagedBy   = "Terraform"
      Purpose     = "OIDC authentication for Terraform operations"
    }
  )
}

# Attach AWS managed ReadOnly policy as baseline
resource "aws_iam_role_policy_attachment" "readonly" {
  count      = var.attach_readonly_policy ? 1 : 0
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

# Custom inline policy for Terraform operations
resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-${var.environment}-${var.layer}-permissions"
  role = aws_iam_role.terraform.id

  policy = var.custom_policy_json
}

# Optional: Attach additional managed policies
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.terraform.name
  policy_arn = each.value
}
