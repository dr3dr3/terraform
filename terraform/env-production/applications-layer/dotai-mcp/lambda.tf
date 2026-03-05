# =============================================================================
# Lambda Function and Function URL - dotai MCP Server (Production)
# =============================================================================

resource "aws_lambda_function" "this" {
  function_name = local.name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"

  # Image is pushed to ECR by the dotai-mcp GitHub Actions deploy workflow.
  # On first apply the ECR repo will be empty; push an image before invoking.
  image_uri = "${aws_ecr_repository.this.repository_url}:latest"

  memory_size = 256 # Sufficient for a stateless prompts server
  timeout     = 30  # MCP requests resolve well within this limit

  environment {
    variables = {
      MCP_TRANSPORT  = "http"
      MCP_AUTH_TOKEN = var.mcp_auth_token
    }
  }
}

# Function URL — no API Gateway required.
# Bearer-token auth is enforced by the application middleware, not AWS IAM.
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"
}
