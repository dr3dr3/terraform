# =============================================================================
# Outputs - Production Account GitHub Actions OIDC Role
# Per ADR-013: Export github_actions_prod_platform_role_arn for workflow config
# =============================================================================

output "github_actions_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_oidc_provider_url" {
  description = "URL of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.url
}

output "github_actions_prod_platform_role_arn" {
  description = "ARN of the GitHub Actions role for production platform layer (use this in GitHub Actions workflow)"
  value       = aws_iam_role.github_actions_prod_platform.arn
}

output "github_actions_prod_platform_role_name" {
  description = "Name of the GitHub Actions role for production platform layer"
  value       = aws_iam_role.github_actions_prod_platform.name
}

output "account_id" {
  description = "AWS account ID where the role is created (should be the production account)"
  value       = data.aws_caller_identity.current.account_id
}
