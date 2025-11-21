terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "Datafaced"

    workspaces {
      name = "development-foundation-iam-roles"
    }
  }

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
      Environment = "Development"
      ManagedBy   = "Terraform"
      Purpose     = "IAM-Roles-PermissionSets"
    }
  }
}

locals {
  environment = "development"
  layers      = ["foundation", "platform", "application"]
  
  # Get policy templates from module
  policy_templates = {
    foundation  = jsondecode(data.local_file.foundation_policy.content)
    platform    = jsondecode(data.local_file.platform_policy.content)
    application = jsondecode(data.local_file.application_policy.content)
  }
}

# Read policy templates from module
data "local_file" "foundation_policy" {
  filename = "${path.module}/../../../terraform-modules/permission-sets/policies.tf"
}

data "local_file" "platform_policy" {
  filename = "${path.module}/../../../terraform-modules/permission-sets/policies.tf"
}

data "local_file" "application_policy" {
  filename = "${path.module}/../../../terraform-modules/permission-sets/policies.tf"
}

# Foundation Layer Roles
module "foundation_cicd_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"
  role_name            = "terraform-${local.environment}-foundation-cicd-role"
  environment          = local.environment
  layer                = "foundation"
  context              = "cicd"
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_url    = var.oidc_provider_url
  oidc_audience        = var.oidc_audience
  cicd_subject_claim   = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
  session_duration     = 7200 # 2 hours
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FoundationNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpc*",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnet*",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*",
          "ec2:ModifySecurityGroup*",
          "ec2:CreateNetworkAcl*",
          "ec2:DeleteNetworkAcl*",
          "ec2:*TransitGateway*",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "FoundationDNS"
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Sid    = "FoundationKMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

module "foundation_human_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"

  role_name               = "terraform-${local.environment}-foundation-human-role"
  environment             = local.environment
  layer                   = "foundation"
  context                 = "human"
  oidc_provider_arn       = var.oidc_provider_arn
  oidc_provider_url       = var.oidc_provider_url
  oidc_audience           = var.oidc_audience
  human_subject_pattern   = "repo:${var.github_org}/${var.github_repo}:*"
  session_duration        = 43200 # 12 hours - generous for dev
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FoundationNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpc*",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnet*",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*",
          "ec2:ModifySecurityGroup*",
          "ec2:CreateNetworkAcl*",
          "ec2:DeleteNetworkAcl*",
          "ec2:*TransitGateway*",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "FoundationDNS"
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Sid    = "FoundationKMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Platform Layer Roles
module "platform_cicd_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"

  role_name               = "terraform-${local.environment}-platform-cicd-role"
  environment             = local.environment
  layer                   = "platform"
  context                 = "cicd"
  oidc_provider_arn       = var.oidc_provider_arn
  oidc_provider_url       = var.oidc_provider_url
  oidc_audience           = var.oidc_audience
  cicd_subject_claim      = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
  session_duration        = 7200 # 2 hours
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PlatformEKS"
        Effect = "Allow"
        Action = [
          "eks:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformRDS"
        Effect = "Allow"
        Action = [
          "rds:*",
          "rds-db:connect"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:*",
          "ssm:*Parameter*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

module "platform_human_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"

  role_name               = "terraform-${local.environment}-platform-human-role"
  environment             = local.environment
  layer                   = "platform"
  context                 = "human"
  oidc_provider_arn       = var.oidc_provider_arn
  oidc_provider_url       = var.oidc_provider_url
  oidc_audience           = var.oidc_audience
  human_subject_pattern   = "repo:${var.github_org}/${var.github_repo}:*"
  session_duration        = 43200 # 12 hours
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PlatformEKS"
        Effect = "Allow"
        Action = [
          "eks:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformRDS"
        Effect = "Allow"
        Action = [
          "rds:*",
          "rds-db:connect"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "PlatformSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:*",
          "ssm:*Parameter*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Application Layer Roles
module "application_cicd_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"

  role_name               = "terraform-${local.environment}-application-cicd-role"
  environment             = local.environment
  layer                   = "application"
  context                 = "cicd"
  oidc_provider_arn       = var.oidc_provider_arn
  oidc_provider_url       = var.oidc_provider_url
  oidc_audience           = var.oidc_audience
  cicd_subject_claim      = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
  session_duration        = 7200 # 2 hours
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ApplicationLambda"
        Effect = "Allow"
        Action = [
          "lambda:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationS3"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationAPI"
        Effect = "Allow"
        Action = [
          "apigateway:*",
          "execute-api:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationSQSSNS"
        Effect = "Allow"
        Action = [
          "sqs:*",
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

module "application_human_role" {
  source = "../../../../terraform-modules/terraform-oidc-role"

  role_name               = "terraform-${local.environment}-application-human-role"
  environment             = local.environment
  layer                   = "application"
  context                 = "human"
  oidc_provider_arn       = var.oidc_provider_arn
  oidc_provider_url       = var.oidc_provider_url
  oidc_audience           = var.oidc_audience
  human_subject_pattern   = "repo:${var.github_org}/${var.github_repo}:*"
  session_duration        = 43200 # 12 hours
  permission_boundary_arn = var.permission_boundary_arn
  attach_readonly_policy  = true

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ApplicationLambda"
        Effect = "Allow"
        Action = [
          "lambda:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationS3"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationAPI"
        Effect = "Allow"
        Action = [
          "apigateway:*",
          "execute-api:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationSQSSNS"
        Effect = "Allow"
        Action = [
          "sqs:*",
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Permission Sets for IAM Identity Center
module "foundation_permission_set" {
  source = "../../../../terraform-modules/permission-set"

  permission_set_name = "DevFoundationAdmin"
  description         = "Development Foundation layer administrative access"
  environment         = local.environment
  layer               = "foundation"
  session_duration    = "PT12H" # 12 hours

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FoundationNetworking"
        Effect = "Allow"
        Action = [
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*SecurityGroup*",
          "ec2:*InternetGateway*",
          "ec2:*NatGateway*",
          "ec2:*RouteTable*",
          "route53:*",
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })

  account_assignments = var.foundation_account_assignments

  tags = var.tags
}

module "platform_permission_set" {
  source = "../../../../terraform-modules/permission-set"

  permission_set_name = "DevPlatformAdmin"
  description         = "Development Platform layer administrative access"
  environment         = local.environment
  layer               = "platform"
  session_duration    = "PT12H"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PlatformServices"
        Effect = "Allow"
        Action = [
          "eks:*",
          "rds:*",
          "elasticloadbalancing:*",
          "secretsmanager:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })

  account_assignments = var.platform_account_assignments

  tags = var.tags
}

module "application_permission_set" {
  source = "../../../../terraform-modules/permission-set"

  permission_set_name = "DevApplicationAdmin"
  description         = "Development Application layer administrative access"
  environment         = local.environment
  layer               = "application"
  session_duration    = "PT12H"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ApplicationServices"
        Effect = "Allow"
        Action = [
          "lambda:*",
          "s3:*",
          "dynamodb:*",
          "apigateway:*",
          "sqs:*",
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })

  account_assignments = var.application_account_assignments

  tags = var.tags
}
