# =============================================================================
# Variables - dotai MCP Server (Production)
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment_suffix" {
  description = "Suffix appended to resource names to distinguish from production (empty string in production)"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner tag applied to all resources"
  type        = string
  default     = "platform"
}

variable "mcp_auth_token" {
  description = "Bearer token required by MCP clients to authenticate with the Lambda Function URL. Must be set as a sensitive variable in the Terraform Cloud workspace."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mcp_auth_token) > 0
    error_message = "mcp_auth_token must not be empty. Set it as a sensitive Terraform variable in the Terraform Cloud workspace."
  }
}

variable "lambda_image_uri" {
  description = "Container image URI for the Lambda function (must be a private ECR image in the same account). Push an initial image to ECR before the first apply, then set this variable in the Terraform Cloud workspace. GitHub Actions owns all subsequent image updates via update-function-code."
  type        = string
}
