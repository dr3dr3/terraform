# =============================================================================
# SSM Parameter Store - dotai MCP Auth Token (Production)
# =============================================================================
# Stores the bearer token as a SecureString so it can be rotated without
# a Lambda redeployment. The Lambda IAM role has ssm:GetParameter access.
# =============================================================================

resource "aws_ssm_parameter" "auth_token" {
  name  = "/${local.name}/MCP_AUTH_TOKEN"
  type  = "SecureString"
  value = var.mcp_auth_token
}
