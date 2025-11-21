# Policy templates for different layers
# These are baseline permissions - customize based on your specific needs

locals {
  # Foundation layer - VPC, networking, security groups
  foundation_policy = {
    dev = jsonencode({
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
    staging = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "FoundationNetworking"
          Effect = "Allow"
          Action = [
            "ec2:CreateVpc",
            "ec2:ModifyVpc*",
            "ec2:CreateSubnet",
            "ec2:ModifySubnet*",
            "ec2:CreateSecurityGroup",
            "ec2:ModifySecurityGroup*",
            "ec2:AuthorizeSecurityGroup*",
            "ec2:RevokeSecurityGroup*",
            "ec2:CreateTags"
          ]
          Resource = "*"
        },
        {
          Sid      = "FoundationDelete"
          Effect   = "Deny"
          Action   = ["ec2:DeleteVpc", "ec2:DeleteSubnet"]
          Resource = "*"
        }
      ]
    })
    production = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "FoundationReadWrite"
          Effect = "Allow"
          Action = [
            "ec2:ModifyVpc*",
            "ec2:ModifySubnet*",
            "ec2:CreateSecurityGroup",
            "ec2:ModifySecurityGroup*",
            "ec2:AuthorizeSecurityGroup*",
            "ec2:RevokeSecurityGroup*",
            "ec2:CreateTags"
          ]
          Resource = "*"
        },
        {
          Sid      = "FoundationDeny"
          Effect   = "Deny"
          Action   = ["ec2:Delete*", "ec2:Terminate*"]
          Resource = "*"
        }
      ]
    })
  }

  # Platform layer - EKS, RDS, shared services
  platform_policy = {
    dev = jsonencode({
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
            "iam:PassRole"
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
    staging = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "PlatformModify"
          Effect = "Allow"
          Action = [
            "eks:UpdateClusterConfig",
            "eks:UpdateNodegroupConfig",
            "rds:ModifyDBInstance",
            "elasticloadbalancing:ModifyLoadBalancer*"
          ]
          Resource = "*"
        },
        {
          Sid      = "PlatformDeleteDeny"
          Effect   = "Deny"
          Action   = ["eks:DeleteCluster", "rds:DeleteDBInstance"]
          Resource = "*"
        }
      ]
    })
    production = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "PlatformReadModify"
          Effect = "Allow"
          Action = [
            "eks:DescribeCluster",
            "eks:UpdateClusterConfig",
            "rds:DescribeDBInstances",
            "rds:ModifyDBInstance"
          ]
          Resource = "*"
        },
        {
          Sid      = "PlatformDeleteDeny"
          Effect   = "Deny"
          Action   = ["*:Delete*", "*:Terminate*"]
          Resource = "*"
        }
      ]
    })
  }

  # Application layer - Lambda, S3, application resources
  application_policy = {
    dev = jsonencode({
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
    staging = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "ApplicationModify"
          Effect = "Allow"
          Action = [
            "lambda:UpdateFunctionCode",
            "lambda:UpdateFunctionConfiguration",
            "s3:PutObject",
            "s3:DeleteObject",
            "dynamodb:UpdateTable"
          ]
          Resource = "*"
        }
      ]
    })
    production = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "ApplicationRead"
          Effect = "Allow"
          Action = [
            "lambda:GetFunction",
            "lambda:UpdateFunctionCode",
            "s3:GetObject",
            "s3:PutObject",
            "dynamodb:DescribeTable"
          ]
          Resource = "*"
        },
        {
          Sid      = "ApplicationDeleteDeny"
          Effect   = "Deny"
          Action   = ["*:Delete*", "lambda:DeleteFunction"]
          Resource = "*"
        }
      ]
    })
  }
}
