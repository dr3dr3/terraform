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
  description = "Bearer token required by MCP clients to authenticate with the Lambda Function URL"
  type        = string
  sensitive   = true
}
