data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_ssoadmin_instances" "main" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  partition         = data.aws_partition.current.partition
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]

  # Common tags for all resources
  common_tags = {
    Owner         = var.owner
    Environment   = var.environment
    Layer         = var.layer
    ManagedBy    = var.managed_by
  }
}

# Create IAM Identity Center Groups
resource "aws_identitystore_group" "admin" {
  identity_store_id = local.identity_store_id
  display_name      = "Administrators"
  description       = "Full administrative access to all AWS resources"
}

resource "aws_identitystore_group" "platform_engineers" {
  identity_store_id = local.identity_store_id
  display_name      = "Platform-Engineers"
  description       = "Platform engineers with permissions to create and manage EKS clusters"
}

resource "aws_identitystore_group" "readonly" {
  identity_store_id = local.identity_store_id
  display_name      = "ReadOnly"
  description       = "Read-only access to all AWS resources"
}

# Admin Permission Set - Full administrative access
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Provides full administrative access to AWS services and resources"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = merge(
    local.common_tags,
    {
      name    = "AdministratorAccess"
      purpose = "Full administrative access"
    }
  )
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# Platform Engineers Permission Set - EKS focused permissions
resource "aws_ssoadmin_permission_set" "platform_engineers" {
  name             = "PlatformEngineerAccess"
  description      = "Platform engineers with permissions to create and manage EKS clusters and related infrastructure"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours

  tags = merge(
    local.common_tags,
    {
      name    = "PlatformEngineerAccess"
      purpose = "EKS cluster management and platform infrastructure"
    }
  )
}

resource "aws_ssoadmin_permission_set_inline_policy" "platform_engineers" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn
  inline_policy      = data.aws_iam_policy_document.platform_engineers.json
}

# ReadOnly Permission Set - Read-only access to all resources
resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnlyAccess"
  description      = "Provides read-only access to all AWS services and resources"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H" # 12 hours

  tags = merge(
    local.common_tags,
    {
      name    = "ReadOnlyAccess"
      purpose = "Read-only access for auditing and monitoring"
    }
  )
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

# Assign Permission Sets to Groups in Management Account
resource "aws_ssoadmin_account_assignment" "admin_management" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.admin.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_engineers_management" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn

  principal_id   = aws_identitystore_group.platform_engineers.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "readonly_management" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = aws_identitystore_group.readonly.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

# Optional: Assign to other accounts if specified
resource "aws_ssoadmin_account_assignment" "admin_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.admin.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "platform_engineers_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn

  principal_id   = aws_identitystore_group.platform_engineers.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "readonly_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = aws_identitystore_group.readonly.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}
