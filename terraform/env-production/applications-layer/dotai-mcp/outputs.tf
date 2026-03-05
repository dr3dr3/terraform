# =============================================================================
# Outputs - dotai MCP Server (Production)
# =============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL — used in the dotai-mcp GitHub Actions deploy workflow (AWS_ECR_REPOSITORY)"
  value       = aws_ecr_repository.this.repository_url
}

output "lambda_function_name" {
  description = "Lambda function name — used in the GitHub Actions deploy workflow (AWS_LAMBDA_FUNCTION_NAME)"
  value       = aws_lambda_function.this.function_name
}

output "function_url" {
  description = "Lambda Function URL — configure this in Claude Desktop / Claude Code as the MCP server endpoint"
  value       = aws_lambda_function_url.this.function_url
}
