output "oidc_provider_arn" {
  description = "ARN of the Terraform Cloud OIDC provider"
  value       = data.aws_iam_openid_connect_provider.terraform_cloud.arn
}

output "oidc_provider_url" {
  description = "URL of the Terraform Cloud OIDC provider"
  value       = local.tfc_hostname
}

output "dev_foundation_cicd_role_arn" {
  description = "ARN of the development foundation CICD role"
  value       = module.dev_foundation_cicd_role.role_arn
}

output "dev_foundation_cicd_role_name" {
  description = "Name of the development foundation CICD role"
  value       = module.dev_foundation_cicd_role.role_name
}

output "staging_foundation_cicd_role_arn" {
  description = "ARN of the staging foundation CICD role"
  value       = module.staging_foundation_cicd_role.role_arn
}

output "staging_foundation_cicd_role_name" {
  description = "Name of the staging foundation CICD role"
  value       = module.staging_foundation_cicd_role.role_name
}

output "prod_foundation_cicd_role_arn" {
  description = "ARN of the production foundation CICD role"
  value       = module.prod_foundation_cicd_role.role_arn
}

output "prod_foundation_cicd_role_name" {
  description = "Name of the production foundation CICD role"
  value       = module.prod_foundation_cicd_role.role_name
}

output "account_id" {
  description = "AWS account ID where roles are created"
  value       = local.account_id
}
