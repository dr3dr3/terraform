output "oidc_provider_arn" {
  description = "ARN of the Terraform Cloud OIDC provider in the production account"
  value       = aws_iam_openid_connect_provider.terraform_cloud.arn
}

output "oidc_provider_url" {
  description = "URL of the Terraform Cloud OIDC provider"
  value       = "https://${local.tfc_hostname}"
}

output "account_id" {
  description = "AWS account ID where roles are created (production account)"
  value       = local.account_id
}

# Foundation Layer Role
output "foundation_cicd_role_arn" {
  description = "ARN of the production foundation CICD role"
  value       = aws_iam_role.foundation_cicd.arn
}

output "foundation_cicd_role_name" {
  description = "Name of the production foundation CICD role"
  value       = aws_iam_role.foundation_cicd.name
}

# Platform Layer Role
output "platform_cicd_role_arn" {
  description = "ARN of the production platform CICD role"
  value       = aws_iam_role.platform_cicd.arn
}

output "platform_cicd_role_name" {
  description = "Name of the production platform CICD role"
  value       = aws_iam_role.platform_cicd.name
}

# Applications Layer Role
output "applications_cicd_role_arn" {
  description = "ARN of the production applications CICD role"
  value       = aws_iam_role.applications_cicd.arn
}

output "applications_cicd_role_name" {
  description = "Name of the production applications CICD role"
  value       = aws_iam_role.applications_cicd.name
}
