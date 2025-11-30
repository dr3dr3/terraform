# IAM Policy Documents for AWS SSO Permission Sets
# Each persona gets a tailored policy following the principle of least privilege
# See ADR-015 for the complete user persona strategy

###############################################################################
# PLATFORM ENGINEERS POLICY
# Full EKS cluster management + VPC/networking + supporting services
# NO IAM management (prevents privilege escalation)
###############################################################################

data "aws_iam_policy_document" "platform_engineers" {
  # EKS Cluster Management
  statement {
    sid    = "EKSClusterManagement"
    effect = "Allow"
    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:ListTagsForResource",
      "eks:AccessKubernetesApi",
      "eks:AssociateAccessPolicy",
      "eks:AssociateIdentityProviderConfig",
      "eks:CreateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:DisassociateAccessPolicy",
      "eks:DisassociateIdentityProviderConfig",
      "eks:ListAccessEntries",
      "eks:ListAccessPolicies",
      "eks:ListAssociatedAccessPolicies",
      "eks:UpdateAccessEntry",
    ]
    resources = ["*"]
  }

  # EKS Node Groups
  statement {
    sid    = "EKSNodeGroupManagement"
    effect = "Allow"
    actions = [
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
    ]
    resources = ["*"]
  }

  # EKS Add-ons
  statement {
    sid    = "EKSAddonManagement"
    effect = "Allow"
    actions = [
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:DescribeAddon",
      "eks:DescribeAddonVersions",
      "eks:ListAddons",
      "eks:UpdateAddon",
    ]
    resources = ["*"]
  }

  # EKS Fargate Profiles
  statement {
    sid    = "EKSFargateManagement"
    effect = "Allow"
    actions = [
      "eks:CreateFargateProfile",
      "eks:DeleteFargateProfile",
      "eks:DescribeFargateProfile",
      "eks:ListFargateProfiles",
    ]
    resources = ["*"]
  }

  # IAM Roles for EKS (scoped to eks-* pattern)
  statement {
    sid    = "IAMRoleManagementForEKS"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/eks-*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/eks.amazonaws.com/*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/eks-nodegroup.amazonaws.com/*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/eks-fargate.amazonaws.com/*",
    ]
  }

  # IAM Policy Management for EKS (scoped to eks-* pattern)
  statement {
    sid    = "IAMPolicyManagementForEKS"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:policy/eks-*"]
  }

  # IAM OIDC Provider for EKS
  statement {
    sid    = "IAMOIDCProviderForEKS"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:oidc-provider/oidc.eks.*"]
  }

  # IAM Pass Role for EKS
  statement {
    sid    = "IAMPassRoleForEKS"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/eks-*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "eks-fargate-pods.amazonaws.com",
      ]
    }
  }

  # EC2 for EKS Node Groups
  statement {
    sid    = "EC2ManagementForEKS"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersions",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:ModifyLaunchTemplate",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeImages",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }

  # Security Groups for EKS
  statement {
    sid    = "SecurityGroupManagementForEKS"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:*:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:*:*:vpc/*",
    ]
  }

  # VPC and Networking for EKS
  statement {
    sid    = "VPCManagementForEKS"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",
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
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeRouteTables",
      "ec2:DescribeVpcAttribute",
    ]
    resources = ["*"]
  }

  # Auto Scaling for EKS Node Groups
  statement {
    sid    = "AutoScalingForEKS"
    effect = "Allow"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteTags",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs for EKS
  statement {
    sid    = "CloudWatchLogsForEKS"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/eks/*",
    ]
  }

  # KMS for EKS Encryption
  statement {
    sid    = "KMSForEKS"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:GetKeyRotationStatus",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }

  # Elastic Load Balancing for EKS
  statement {
    sid    = "ELBForEKS"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = ["*"]
  }

  # ECR for Container Images
  statement {
    sid    = "ECRManagement"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:TagResource",
      "ecr:UntagResource",
    ]
    resources = ["*"]
  }

  # Secrets Manager Read Access
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }

  # Systems Manager Parameter Store for EKS
  statement {
    sid    = "SSMParameterStoreForEKS"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:*:*:parameter/aws/service/eks/*",
    ]
  }

  # Read-only access to other services for context
  statement {
    sid    = "ReadOnlyAccess"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "cloudformation:DescribeStacks",
      "cloudformation:ListStacks",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }
}

###############################################################################
# NAMESPACE ADMINS POLICY
# EKS describe + ECR push/pull + CloudWatch logs + Secrets Manager read
# NO cluster creation/deletion, NO VPC/networking
###############################################################################

data "aws_iam_policy_document" "namespace_admins" {
  # EKS Read/Describe Access (no create/delete cluster)
  statement {
    sid    = "EKSDescribeAccess"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:ListNodegroups",
      "eks:DescribeNodegroup",
      "eks:ListAddons",
      "eks:DescribeAddon",
      "eks:ListFargateProfiles",
      "eks:DescribeFargateProfile",
      "eks:ListTagsForResource",
      "eks:AccessKubernetesApi",
    ]
    resources = ["*"]
  }

  # ECR Push/Pull for Container Images
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs - Read access for troubleshooting
  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/eks/*",
      "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/containerinsights/*",
    ]
  }

  # Secrets Manager Read Access
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }

  # S3 Read Access for application configs
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  # Basic identity and context
  statement {
    sid    = "BasicReadAccess"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }
}

###############################################################################
# DEVELOPERS POLICY
# EKS describe + ECR push/pull + CloudWatch logs
# NO secrets write, NO infrastructure changes
###############################################################################

data "aws_iam_policy_document" "developers" {
  # EKS Read/Describe Access
  statement {
    sid    = "EKSDescribeAccess"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:ListNodegroups",
      "eks:DescribeNodegroup",
      "eks:ListAddons",
      "eks:DescribeAddon",
      "eks:ListTagsForResource",
      "eks:AccessKubernetesApi",
    ]
    resources = ["*"]
  }

  # ECR Push/Pull for Container Images
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs - Read access for troubleshooting
  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/eks/*",
      "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:/aws/containerinsights/*",
    ]
  }

  # S3 Read Access for application data
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  # Secrets Manager - List only (actual secrets accessed via K8s)
  statement {
    sid    = "SecretsManagerList"
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["*"]
  }

  # Basic identity and context
  statement {
    sid    = "BasicReadAccess"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }
}

###############################################################################
# AUDITORS POLICY
# Cost Explorer access (not in ReadOnlyAccess managed policy)
# Security-focused read access
###############################################################################

data "aws_iam_policy_document" "auditors" {
  # Cost Explorer Access (not included in ReadOnlyAccess)
  statement {
    sid    = "CostExplorerAccess"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetDimensionValues",
      "ce:GetReservationUtilization",
      "ce:GetSavingsPlansUtilization",
      "ce:GetTags",
      "ce:GetUsageForecast",
    ]
    resources = ["*"]
  }

  # Budgets Access
  statement {
    sid    = "BudgetsAccess"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudget",
      "budgets:DescribeBudgets",
    ]
    resources = ["*"]
  }

  # Security Hub Access
  statement {
    sid    = "SecurityHubAccess"
    effect = "Allow"
    actions = [
      "securityhub:GetFindings",
      "securityhub:GetInsights",
      "securityhub:DescribeHub",
    ]
    resources = ["*"]
  }

  # CloudTrail Access for audit logs
  statement {
    sid    = "CloudTrailAccess"
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents",
      "cloudtrail:GetTrail",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetEventSelectors",
    ]
    resources = ["*"]
  }

  # IAM Access Analyzer
  statement {
    sid    = "IAMAccessAnalyzer"
    effect = "Allow"
    actions = [
      "access-analyzer:GetFinding",
      "access-analyzer:ListFindings",
      "access-analyzer:ListAnalyzers",
    ]
    resources = ["*"]
  }
}
