locals {
  tfc_organization = var.tfc_organization
  tfc_hostname     = "app.terraform.io"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Create OIDC provider for Terraform Cloud
resource "aws_iam_openid_connect_provider" "terraform_cloud" {
  url             = "https://${local.tfc_hostname}"
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

# Create role for Terraform Cloud to assume
resource "aws_iam_role" "terraform_cloud_oidc" {
  name               = "terraform-cloud-oidc-role"
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
            "${local.tfc_hostname}:aud" = "aws.workload.identity"
          }
          StringLike = {
            "${local.tfc_hostname}:sub" = "organization:${local.tfc_organization}:project:*:workspace:*:run_phase:*"
          }
        }
      }
    ]
  })

  tags = merge(
    {
      Name    = "terraform-cloud-oidc-role"
      Purpose = "Terraform Cloud OIDC authentication"
    },
    {
      Owner      = var.owner
    }
  )
}

# Attach permissions to the role
# For management account IAM Identity Center operations
resource "aws_iam_role_policy" "terraform_cloud_oidc" {
  name   = "terraform-cloud-oidc-policy"
  role   = aws_iam_role.terraform_cloud_oidc.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageIAMIdentityCenter"
        Effect = "Allow"
        Action = [
          "identitystore:*",
          "sso:*",
          "ssoadmin:*"
        ]
        Resource = "*"
      }
    ]
  })
}

