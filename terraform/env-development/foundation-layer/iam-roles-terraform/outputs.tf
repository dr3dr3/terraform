output "foundation_cicd_role_arn" {
  description = "ARN of the Foundation CICD role"
  value       = module.foundation_cicd_role.role_arn
}

output "foundation_human_role_arn" {
  description = "ARN of the Foundation Human role"
  value       = module.foundation_human_role.role_arn
}

output "platform_cicd_role_arn" {
  description = "ARN of the Platform CICD role"
  value       = module.platform_cicd_role.role_arn
}

output "platform_human_role_arn" {
  description = "ARN of the Platform Human role"
  value       = module.platform_human_role.role_arn
}

output "application_cicd_role_arn" {
  description = "ARN of the Application CICD role"
  value       = module.application_cicd_role.role_arn
}

output "application_human_role_arn" {
  description = "ARN of the Application Human role"
  value       = module.application_human_role.role_arn
}

output "foundation_permission_set_arn" {
  description = "ARN of the Foundation Permission Set"
  value       = module.foundation_permission_set.permission_set_arn
}

output "platform_permission_set_arn" {
  description = "ARN of the Platform Permission Set"
  value       = module.platform_permission_set.permission_set_arn
}

output "application_permission_set_arn" {
  description = "ARN of the Application Permission Set"
  value       = module.application_permission_set.permission_set_arn
}
