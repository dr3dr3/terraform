# =============================================================================
# IAM Role and Policies - dotai Lambda (Production)
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
