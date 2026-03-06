# =============================================================================
# IAM Policy Document for GitHub Actions EKS Provisioning - Production Account
# Per ADR-013: Required permissions for EKS Auto Mode clusters
# =============================================================================

data "aws_iam_policy_document" "github_actions_prod_platform_permissions" {

  # ---------------------------------------------------------------------------
  # EKS Permissions (per ADR-013)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "EKSFullAccess"
    effect = "Allow"
    actions = [
      "eks:*"
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # IAM Permissions (per ADR-013)
  # Required for EKS cluster role, node role, and IRSA
  # ---------------------------------------------------------------------------
  statement {
    sid    = "IAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRoleTags",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "arn:aws:iam::*:role/eks-*",
      "arn:aws:iam::*:role/EKS*",
      "arn:aws:iam::*:role/*-eks-*",
      "arn:aws:iam::*:role/production-*",
      "arn:aws:iam::*:role/prod-*",
    ]
  }

  statement {
    sid    = "IAMOIDCProviderManagement"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
    ]
    resources = ["arn:aws:iam::*:oidc-provider/*"]
  }

  statement {
    sid    = "IAMPolicyManagement"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
    ]
    resources = [
      "arn:aws:iam::*:policy/eks-*",
      "arn:aws:iam::*:policy/EKS*",
    ]
  }

  statement {
    sid    = "IAMServiceLinkedRole"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "eks-fargate.amazonaws.com",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # EC2/VPC Permissions (per ADR-013)
  # Required for EKS networking infrastructure
  # ---------------------------------------------------------------------------
  statement {
    sid    = "VPCManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SubnetManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:ModifySubnetAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecurityGroupManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TagManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AvailabilityZones"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "InternetGatewayManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DescribeInternetGateways",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RouteTableManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ElasticIPManagement"
    effect = "Allow"
    actions = [
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NATGatewayManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # CloudWatch Permissions (per ADR-013)
  # Required for EKS control plane logging
  # ---------------------------------------------------------------------------
  statement {
    sid    = "CloudWatchLogsManagement"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagLogGroup",
      "logs:ListTagsLogGroup",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/eks/*",
    ]
  }

  # ---------------------------------------------------------------------------
  # Additional EC2 Permissions for EKS
  # Required for describing resources during Terraform planning
  # ---------------------------------------------------------------------------
  statement {
    sid    = "EC2DescribePermissions"
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribePrefixLists",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcClassicLink",
      "ec2:DescribeVpcClassicLinkDnsSupport",
      "ec2:DescribeVpcEndpoints",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # STS Permissions
  # Required for Terraform to verify caller identity
  # ---------------------------------------------------------------------------
  statement {
    sid    = "STSGetCallerIdentity"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # KMS Permissions (for EKS secrets encryption)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "KMSForEKS"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ScheduleKeyDeletion",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]
  }
}

# =============================================================================
# Policy Document: GitHub Actions Production Applications Layer
# Used by: github-actions-prod-applications role
# Grants: ECR, Lambda, IAM (scoped), SSM, STS — sufficient for dotai-mcp bootstrap
# =============================================================================
data "aws_iam_policy_document" "github_actions_prod_applications_permissions" {

  statement {
    sid       = "STSGetCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # ECR — create repository, push bootstrap image, manage lifecycle policy
  # ---------------------------------------------------------------------------
  statement {
    sid    = "ECRRepositoryManagement"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:ListTagsForResource",
      "ecr:PutLifecyclePolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:PutImageScanningConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRImagePush"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
    ]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # Lambda — create function, update code, manage function URL
  # ---------------------------------------------------------------------------
  statement {
    sid    = "LambdaManagement"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:CreateFunctionUrlConfig",
      "lambda:UpdateFunctionUrlConfig",
      "lambda:DeleteFunctionUrlConfig",
      "lambda:GetFunctionUrlConfig",
      "lambda:InvokeFunction",
    ]
    resources = ["arn:aws:lambda:*:*:function:dotai*"]
  }

  statement {
    sid       = "LambdaWaitForUpdate"
    effect    = "Allow"
    actions   = ["lambda:GetFunctionConfiguration"]
    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # IAM — create/manage the Lambda execution role (scoped to dotai prefix)
  # ---------------------------------------------------------------------------
  statement {
    sid    = "IAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = [
      "arn:aws:iam::*:role/dotai*",
    ]
  }

  statement {
    sid    = "IAMPolicyRead"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
  }

  # ---------------------------------------------------------------------------
  # SSM — store and manage the MCP auth token SecureString
  # ---------------------------------------------------------------------------
  statement {
    sid    = "SSMParameterManagement"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:AddTagsToResource",
      "ssm:ListTagsForResource",
    ]
    resources = ["arn:aws:ssm:*:*:parameter/dotai*"]
  }

  statement {
    sid    = "KMSForSSMSecureString"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}
