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
    Owner       = var.owner
    Environment = var.environment
    Layer       = var.layer
    ManagedBy   = var.managed_by
  }

  # Environment access matrix - which groups get access to which accounts
  # Based on ADR-015 User Personas strategy
  environment_access = {
    # Management account - Administrators only
    management = ["admin"]
    # Sandbox - All personas for testing
    sandbox = ["admin", "platform_engineers", "namespace_admins", "developers", "auditors"]
    # Development - All except management-only roles
    development = ["admin", "platform_engineers", "namespace_admins", "developers", "auditors"]
    # Staging - All except management-only roles (future)
    staging = ["admin", "platform_engineers", "namespace_admins", "developers", "auditors"]
    # Production - Restricted access
    production = ["admin", "platform_engineers", "auditors"]
  }
}

###############################################################################
# IDENTITY STORE USERS
# Users managed by Terraform in IAM Identity Center
###############################################################################

resource "aws_identitystore_user" "andre_dreyer" {
  identity_store_id = local.identity_store_id
  user_name         = "andre.dreyer"
  display_name      = "André Dreyer"

  name {
    given_name  = "André"
    family_name = "Dreyer"
  }

  emails {
    value   = "andre.dreyer@datafaced.com"
    primary = true
    type    = "work"
  }

  phone_numbers {
    value   = "+61424579579"
    primary = true
    type    = "work"
  }
}

###############################################################################
# IDENTITY STORE GROUPS
# Groups for organizing users by persona/role
###############################################################################

# Administrator Group - Full access to all AWS and Kubernetes resources
resource "aws_identitystore_group" "admin" {
  identity_store_id = local.identity_store_id
  display_name      = "Administrators"
  description       = "Full administrative access to all AWS services and Kubernetes cluster-admin. For platform owners and break-glass scenarios."
}

# Platform Engineers Group - EKS/Infrastructure management
resource "aws_identitystore_group" "platform_engineers" {
  identity_store_id = local.identity_store_id
  display_name      = "Platform-Engineers"
  description       = "Platform engineers with permissions to create and manage EKS clusters, networking, and platform infrastructure. Maps to Kubernetes cluster-admin."
}

# Namespace Administrators Group - Full namespace control
resource "aws_identitystore_group" "namespace_admins" {
  identity_store_id = local.identity_store_id
  display_name      = "Namespace-Admins"
  description       = "Team leads with full control within their assigned Kubernetes namespaces. Can manage deployments, secrets, and RBAC within namespace scope."
}

# Developers Group - Application deployment
resource "aws_identitystore_group" "developers" {
  identity_store_id = local.identity_store_id
  display_name      = "Developers"
  description       = "Developers who deploy and manage applications. Limited AWS access, can deploy pods but cannot manage secrets directly in Kubernetes."
}

# Auditors Group - Read-only compliance access
resource "aws_identitystore_group" "auditors" {
  identity_store_id = local.identity_store_id
  display_name      = "Auditors"
  description       = "Read-only access for compliance and auditing purposes. Can view all resources but cannot modify anything."
}

###############################################################################
# GROUP MEMBERSHIPS
# Assign users to groups
###############################################################################

# André Dreyer - Administrator (full access)
resource "aws_identitystore_group_membership" "andre_dreyer_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.admin.group_id
  member_id         = aws_identitystore_user.andre_dreyer.user_id
}

# André Dreyer - Platform Engineer
resource "aws_identitystore_group_membership" "andre_dreyer_platform_engineers" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.platform_engineers.group_id
  member_id         = aws_identitystore_user.andre_dreyer.user_id
}

# André Dreyer - Namespace Admin
resource "aws_identitystore_group_membership" "andre_dreyer_namespace_admins" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.namespace_admins.group_id
  member_id         = aws_identitystore_user.andre_dreyer.user_id
}

# André Dreyer - Developer
resource "aws_identitystore_group_membership" "andre_dreyer_developers" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.developers.group_id
  member_id         = aws_identitystore_user.andre_dreyer.user_id
}

# André Dreyer - Auditor
resource "aws_identitystore_group_membership" "andre_dreyer_auditors" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.auditors.group_id
  member_id         = aws_identitystore_user.andre_dreyer.user_id
}

###############################################################################
# PERMISSION SETS
# AWS SSO Permission Sets define what users can do in AWS
###############################################################################

#------------------------------------------------------------------------------
# Administrator Permission Set - EXISTING (not managed by this Terraform)
# The "AdministratorAccess" permission set already exists in IAM Identity Center
# and is managed separately. We reference it via data source for assignments.
#------------------------------------------------------------------------------
data "aws_ssoadmin_permission_set" "admin" {
  instance_arn = local.sso_instance_arn
  name         = "AdministratorAccess"
}

#------------------------------------------------------------------------------
# Platform Engineer Permission Set - EKS and Infrastructure management
#------------------------------------------------------------------------------
resource "aws_ssoadmin_permission_set" "platform_engineers" {
  name             = "PlatformEngineerAccess"
  description      = "Platform engineers with permissions to manage EKS clusters, VPCs, and platform infrastructure. Maps to Kubernetes cluster-admin."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours - workday coverage

  tags = merge(
    local.common_tags,
    {
      Name      = "PlatformEngineerAccess"
      Purpose   = "EKS cluster management and platform infrastructure"
      K8sRole   = "cluster-admin"
      Persona   = "platform-engineer"
      RiskLevel = "high"
    }
  )
}

resource "aws_ssoadmin_permission_set_inline_policy" "platform_engineers" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn
  inline_policy      = data.aws_iam_policy_document.platform_engineers.json
}

#------------------------------------------------------------------------------
# Namespace Administrator Permission Set - Namespace-scoped access
#------------------------------------------------------------------------------
resource "aws_ssoadmin_permission_set" "namespace_admins" {
  name             = "NamespaceAdminAccess"
  description      = "Namespace administrators with EKS describe access and ECR push/pull. Maps to namespace-admin Kubernetes ClusterRole."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H" # 8 hours - workday coverage

  tags = merge(
    local.common_tags,
    {
      Name      = "NamespaceAdminAccess"
      Purpose   = "Kubernetes namespace administration"
      K8sRole   = "namespace-admin"
      Persona   = "namespace-admin"
      RiskLevel = "medium"
    }
  )
}

resource "aws_ssoadmin_permission_set_inline_policy" "namespace_admins" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.namespace_admins.arn
  inline_policy      = data.aws_iam_policy_document.namespace_admins.json
}

#------------------------------------------------------------------------------
# Developer Permission Set - Application deployment focus
#------------------------------------------------------------------------------
resource "aws_ssoadmin_permission_set" "developers" {
  name             = "DeveloperAccess"
  description      = "Developers with EKS describe access, ECR push/pull, and CloudWatch logs. Maps to developer Kubernetes ClusterRole."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H" # 12 hours - convenience for development

  tags = merge(
    local.common_tags,
    {
      Name      = "DeveloperAccess"
      Purpose   = "Application development and deployment"
      K8sRole   = "developer"
      Persona   = "developer"
      RiskLevel = "low"
    }
  )
}

resource "aws_ssoadmin_permission_set_inline_policy" "developers" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developers.arn
  inline_policy      = data.aws_iam_policy_document.developers.json
}

#------------------------------------------------------------------------------
# Auditor Permission Set - Read-only compliance access
#------------------------------------------------------------------------------
resource "aws_ssoadmin_permission_set" "auditors" {
  name             = "AuditorAccess"
  description      = "Read-only access for compliance auditing. Can view all resources including Cost Explorer. Maps to view Kubernetes ClusterRole."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT12H" # 12 hours - long read-only sessions

  tags = merge(
    local.common_tags,
    {
      Name      = "AuditorAccess"
      Purpose   = "Compliance auditing and monitoring"
      K8sRole   = "view"
      Persona   = "auditor"
      RiskLevel = "low"
    }
  )
}

# Auditors get AWS ReadOnlyAccess managed policy
resource "aws_ssoadmin_managed_policy_attachment" "auditors_readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.auditors.arn
  managed_policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

# Additional inline policy for Cost Explorer (not included in ReadOnlyAccess)
resource "aws_ssoadmin_permission_set_inline_policy" "auditors" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.auditors.arn
  inline_policy      = data.aws_iam_policy_document.auditors.json
}

###############################################################################
# ACCOUNT ASSIGNMENTS - MANAGEMENT ACCOUNT
# Assign permission sets to groups in the management account
###############################################################################

resource "aws_ssoadmin_account_assignment" "admin_management" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.admin.group_id
  principal_type = "GROUP"

  target_id   = local.account_id
  target_type = "AWS_ACCOUNT"
}

# Note: Platform Engineers, Namespace Admins, Developers do NOT get management account access
# Only Administrators should access the management/control plane account

###############################################################################
# ACCOUNT ASSIGNMENTS - ADDITIONAL ACCOUNTS (Dev, Staging, Prod, Sandbox)
# Based on environment access matrix defined in ADR-015
###############################################################################

#------------------------------------------------------------------------------
# Administrator assignments to additional accounts
#------------------------------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "admin_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.admin.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

#------------------------------------------------------------------------------
# Platform Engineer assignments to additional accounts
#------------------------------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "platform_engineers_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn

  principal_id   = aws_identitystore_group.platform_engineers.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

#------------------------------------------------------------------------------
# Namespace Admin assignments to non-production accounts only
#------------------------------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "namespace_admins_accounts" {
  for_each = toset(var.non_production_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.namespace_admins.arn

  principal_id   = aws_identitystore_group.namespace_admins.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

#------------------------------------------------------------------------------
# Developer assignments to non-production accounts only
#------------------------------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "developers_accounts" {
  for_each = toset(var.non_production_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developers.arn

  principal_id   = aws_identitystore_group.developers.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

#------------------------------------------------------------------------------
# Auditor assignments to all accounts (including production for compliance)
#------------------------------------------------------------------------------
resource "aws_ssoadmin_account_assignment" "auditors_accounts" {
  for_each = toset(var.additional_account_ids)

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.auditors.arn

  principal_id   = aws_identitystore_group.auditors.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}
