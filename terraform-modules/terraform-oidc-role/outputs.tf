output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.terraform.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.terraform.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.terraform.id
}

output "role_unique_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.terraform.unique_id
}
