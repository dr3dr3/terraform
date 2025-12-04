# Production Account - Foundation Layer - IAM Roles for Terraform
#
# This configuration creates IAM roles in the PRODUCTION AWS account
# that trust the Terraform Cloud OIDC provider in the MANAGEMENT account.
#
# Architecture:
#   Terraform Cloud → OIDC (management account) → Cross-account assume role → Production account role
#
# These roles are used by Terraform Cloud workspaces to provision resources
# in the production AWS account.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Terraform Cloud OIDC provider details
  # The OIDC provider is in the management account
  tfc_hostname = "app.terraform.io"
  tfc_audience = "aws.workload.identity"

  # Common tags for all resources
  common_tags = {
    Owner   = var.owner
    Project = "terraform-infrastructure"
  }
}

# Create an OIDC provider in this production account for Terraform Cloud
# This allows TFC to directly authenticate to this account without cross-account assume
resource "aws_iam_openid_connect_provider" "terraform_cloud" {
  url             = "https://${local.tfc_hostname}"
  client_id_list  = [local.tfc_audience]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = merge(local.common_tags, {
    Name    = "terraform-cloud-oidc"
    Purpose = "Terraform Cloud OIDC authentication"
  })
}

################################################################################
# Foundation Layer Role
# Used for foundation-level resources (IAM, OIDC providers, etc.)
################################################################################

resource "aws_iam_role" "foundation_cicd" {
  name        = "terraform-prod-foundation-cicd-role"
  description = "Terraform Cloud role for production foundation layer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.terraform_cloud.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.tfc_hostname}:aud" = local.tfc_audience
          }
          StringLike = {
            "${local.tfc_hostname}:sub" = "organization:${var.tfc_organization}:project:${var.tfc_project_prod}:workspace:*foundation*:run_phase:*"
          }
        }
      }
    ]
  })

  max_session_duration  = 7200 # 2 hours
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Name        = "terraform-prod-foundation-cicd-role"
    Environment = "production"
    Layer       = "foundation"
    Context     = "cicd"
  })
}

resource "aws_iam_role_policy_attachment" "foundation_readonly" {
  role       = aws_iam_role.foundation_cicd.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "foundation_permissions" {
  name   = "terraform-prod-foundation-permissions"
  role   = aws_iam_role.foundation_cicd.id
  policy = data.aws_iam_policy_document.foundation_permissions.json
}

################################################################################
# Platform Layer Role
# Used for platform-level resources (EKS, RDS, VPC, etc.)
################################################################################

resource "aws_iam_role" "platform_cicd" {
  name        = "terraform-prod-platform-cicd-role"
  description = "Terraform Cloud role for production platform layer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.terraform_cloud.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.tfc_hostname}:aud" = local.tfc_audience
          }
          StringLike = {
            "${local.tfc_hostname}:sub" = "organization:${var.tfc_organization}:project:${var.tfc_project_prod}:workspace:*platform*:run_phase:*"
          }
        }
      }
    ]
  })

  max_session_duration  = 7200 # 2 hours
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Name        = "terraform-prod-platform-cicd-role"
    Environment = "production"
    Layer       = "platform"
    Context     = "cicd"
  })
}

resource "aws_iam_role_policy_attachment" "platform_readonly" {
  role       = aws_iam_role.platform_cicd.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "platform_permissions" {
  name   = "terraform-prod-platform-permissions"
  role   = aws_iam_role.platform_cicd.id
  policy = data.aws_iam_policy_document.platform_permissions.json
}

################################################################################
# Applications Layer Role
# Used for application-level resources (Lambda, API Gateway, etc.)
################################################################################

resource "aws_iam_role" "applications_cicd" {
  name        = "terraform-prod-applications-cicd-role"
  description = "Terraform Cloud role for production applications layer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.terraform_cloud.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.tfc_hostname}:aud" = local.tfc_audience
          }
          StringLike = {
            "${local.tfc_hostname}:sub" = "organization:${var.tfc_organization}:project:${var.tfc_project_prod}:workspace:*application*:run_phase:*"
          }
        }
      }
    ]
  })

  max_session_duration  = 7200 # 2 hours
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Name        = "terraform-prod-applications-cicd-role"
    Environment = "production"
    Layer       = "applications"
    Context     = "cicd"
  })
}

resource "aws_iam_role_policy_attachment" "applications_readonly" {
  role       = aws_iam_role.applications_cicd.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "applications_permissions" {
  name   = "terraform-prod-applications-permissions"
  role   = aws_iam_role.applications_cicd.id
  policy = data.aws_iam_policy_document.applications_permissions.json
}
