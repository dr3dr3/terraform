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
      },
      {
        Sid    = "IAMForSSOAccountAssignment"
        Effect = "Allow"
        Action = [
          "iam:GetSAMLProvider",
          "iam:ListSAMLProviders"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageOIDCRole"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole"
        ]
        Resource = [
          # Bootstrap OIDC role (self-management)
          "arn:aws:iam::*:role/terraform-cloud-*",
          # Terraform workspace roles (VCS-driven CI/CD)
          "arn:aws:iam::*:role/terraform-*-*-cicd-role",
          # Human access roles for break-glass scenarios
          "arn:aws:iam::*:role/terraform-*-*-human-role",
          # GitHub Actions OIDC roles (per ADR-013)
          "arn:aws:iam::*:role/github-actions-*"
        ]
      },
      {
        Sid    = "ManageIAMPoliciesForTerraformRoles"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = [
          "arn:aws:iam::*:policy/terraform-*"
        ]
      },
      {
        Sid    = "ReadOnlyForPlanning"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:ListRoles",
          "iam:ListPolicies"
        ]
        Resource = "*"
      }
    ]
  })
}

