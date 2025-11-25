output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

output "admin_group_id" {
  description = "ID of the Administrators group"
  value       = aws_identitystore_group.admin.group_id
}

output "platform_engineers_group_id" {
  description = "ID of the Platform Engineers group"
  value       = aws_identitystore_group.platform_engineers.group_id
}

output "readonly_group_id" {
  description = "ID of the ReadOnly group"
  value       = aws_identitystore_group.readonly.group_id
}

output "admin_permission_set_arn" {
  description = "ARN of the Administrator Access permission set"
  value       = aws_ssoadmin_permission_set.admin.arn
}

output "platform_engineers_permission_set_arn" {
  description = "ARN of the Platform Engineer Access permission set"
  value       = aws_ssoadmin_permission_set.platform_engineers.arn
}

output "readonly_permission_set_arn" {
  description = "ARN of the ReadOnly Access permission set"
  value       = aws_ssoadmin_permission_set.readonly.arn
}
