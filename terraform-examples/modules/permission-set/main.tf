terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.22.0"
    }
  }
}

data "aws_ssoadmin_instances" "main" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

# Permission Set
resource "aws_ssoadmin_permission_set" "main" {
  name             = var.permission_set_name
  description      = var.description
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration

  tags = merge(
    var.tags,
    {
      Name        = var.permission_set_name
      Environment = var.environment
      Layer       = var.layer
      ManagedBy   = "Terraform"
    }
  )
}

# Attach AWS managed policies
resource "aws_ssoadmin_managed_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  instance_arn       = local.sso_instance_arn
  managed_policy_arn = each.value
  permission_set_arn = aws_ssoadmin_permission_set.main.arn
}

# Attach custom inline policy
resource "aws_ssoadmin_permission_set_inline_policy" "custom" {
  count = var.inline_policy != "" ? 1 : 0

  inline_policy      = var.inline_policy
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.main.arn
}

# Account assignments
resource "aws_ssoadmin_account_assignment" "main" {
  for_each = var.account_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.main.arn

  principal_id   = each.value.principal_id
  principal_type = each.value.principal_type
  target_id      = each.value.account_id
  target_type    = "AWS_ACCOUNT"
}
