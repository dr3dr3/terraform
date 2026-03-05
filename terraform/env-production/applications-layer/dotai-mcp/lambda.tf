# =============================================================================
# Lambda Function and Function URL - dotai MCP Server (Production)
# =============================================================================

resource "aws_lambda_function" "this" {
  function_name = local.name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"

  # Bootstrap: on first apply this defaults to a public AWS placeholder image so
  # Terraform can create the Lambda before any real image exists in ECR.
  # GitHub Actions owns all subsequent image updates via `update-function-code`;
  # the lifecycle block below ensures Terraform never reverts that.
  image_uri = var.lambda_image_uri

  lifecycle {
    ignore_changes = [image_uri]
  }

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
