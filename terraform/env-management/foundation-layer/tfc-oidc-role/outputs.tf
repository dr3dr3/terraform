output "terraform_cloud_oidc_provider_arn" {
  description = "ARN of the Terraform Cloud OIDC provider"
  value       = aws_iam_openid_connect_provider.terraform_cloud.arn
}

output "terraform_cloud_oidc_provider_url" {
  description = "URL of the Terraform Cloud OIDC provider"
  value       = "https://${local.tfc_hostname}"
}

output "terraform_cloud_oidc_role_arn" {
  description = "ARN of the Terraform Cloud OIDC role for Terraform Cloud configuration"
  value       = aws_iam_role.terraform_cloud_oidc.arn
}

output "terraform_cloud_oidc_role_name" {
  description = "Name of the Terraform Cloud OIDC role"
  value       = aws_iam_role.terraform_cloud_oidc.name
}

output "aws_account_id" {
  description = "AWS account ID where OIDC resources are created"
  value       = data.aws_caller_identity.current.account_id
}
