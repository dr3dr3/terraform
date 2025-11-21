output "permission_set_arn" {
  description = "ARN of the Permission Set"
  value       = aws_ssoadmin_permission_set.main.arn
}

output "permission_set_name" {
  description = "Name of the Permission Set"
  value       = aws_ssoadmin_permission_set.main.name
}
