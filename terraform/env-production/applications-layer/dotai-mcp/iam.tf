# =============================================================================
# IAM Role and Policies - dotai Lambda (Production)
# =============================================================================

# Look up the GitHub Actions OIDC provider created by foundation-layer/gha-oidc
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

# =============================================================================
# GitHub Actions deploy role — trusts dr3dr3/dotai-mcp
# Permissions: ECR push + Lambda update-function-code
# =============================================================================
resource "aws_iam_role" "github_actions_deploy" {
  name        = "${local.name}-github-actions-deploy"
  description = "GitHub Actions OIDC role for deploying dotai-mcp container images"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:dr3dr3/dotai-mcp:*"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${local.name}-github-actions-deploy"
    Purpose = "GitHub Actions OIDC deploy role for dotai-mcp"
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  # ECR authentication
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR image push to the dotai repository only
  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.this.arn]
  }

  # Lambda image update
  statement {
    sid    = "LambdaDeploy"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
    ]
    resources = [aws_lambda_function.this.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${local.name}-github-actions-deploy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

# =============================================================================

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Basic execution: write CloudWatch Logs
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to read the auth token from SSM (for rotation without redeployment)
data "aws_iam_policy_document" "ssm_read" {
  statement {
    sid     = "ReadMcpAuthToken"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]

    resources = [aws_ssm_parameter.auth_token.arn]
  }
}

resource "aws_iam_role_policy" "ssm_read" {
  name   = "${local.name}-ssm-read"
  role   = aws_iam_role.lambda.name
  policy = data.aws_iam_policy_document.ssm_read.json
}
