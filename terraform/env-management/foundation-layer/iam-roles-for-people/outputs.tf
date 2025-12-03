###############################################################################
# SSO INSTANCE OUTPUTS
###############################################################################

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

###############################################################################
# USER OUTPUTS
###############################################################################

output "andre_dreyer_user_id" {
  description = "User ID of André Dreyer in the Identity Store"
  value       = aws_identitystore_user.andre_dreyer.user_id
}

output "andre_dreyer_username" {
  description = "Username of André Dreyer"
  value       = aws_identitystore_user.andre_dreyer.user_name
}

###############################################################################
# GROUP ID OUTPUTS
# These IDs are needed to add users to groups
###############################################################################

output "admin_group_id" {
  description = "ID of the Administrators group - Full AWS + K8s cluster-admin access"
  value       = aws_identitystore_group.admin.group_id
}

output "platform_engineers_group_id" {
  description = "ID of the Platform Engineers group - EKS/infrastructure management + K8s cluster-admin"
  value       = aws_identitystore_group.platform_engineers.group_id
}

output "namespace_admins_group_id" {
  description = "ID of the Namespace Admins group - K8s namespace-admin access"
  value       = aws_identitystore_group.namespace_admins.group_id
}

output "developers_group_id" {
  description = "ID of the Developers group - Application deployment + K8s developer access"
  value       = aws_identitystore_group.developers.group_id
}

output "auditors_group_id" {
  description = "ID of the Auditors group - Read-only compliance access + K8s view"
  value       = aws_identitystore_group.auditors.group_id
}

###############################################################################
# PERMISSION SET ARN OUTPUTS
# These ARNs are needed for EKS aws-auth ConfigMap mapping
###############################################################################

output "admin_permission_set_arn" {
  description = "ARN of the Administrator Access permission set (existing, not managed by this Terraform)"
  value       = data.aws_ssoadmin_permission_set.admin.arn
}

output "platform_engineers_permission_set_arn" {
  description = "ARN of the Platform Engineer Access permission set"
  value       = aws_ssoadmin_permission_set.platform_engineers.arn
}

output "namespace_admins_permission_set_arn" {
  description = "ARN of the Namespace Admin Access permission set"
  value       = aws_ssoadmin_permission_set.namespace_admins.arn
}

output "developers_permission_set_arn" {
  description = "ARN of the Developer Access permission set"
  value       = aws_ssoadmin_permission_set.developers.arn
}

output "auditors_permission_set_arn" {
  description = "ARN of the Auditor Access permission set"
  value       = aws_ssoadmin_permission_set.auditors.arn
}

###############################################################################
# PERMISSION SET NAME OUTPUTS
# Names used by AWS SSO to create IAM roles in each account
###############################################################################

output "admin_permission_set_name" {
  description = "Name of the Administrator Access permission set (existing, not managed by this Terraform)"
  value       = data.aws_ssoadmin_permission_set.admin.name
}

output "platform_engineers_permission_set_name" {
  description = "Name of the Platform Engineer Access permission set"
  value       = aws_ssoadmin_permission_set.platform_engineers.name
}

output "namespace_admins_permission_set_name" {
  description = "Name of the Namespace Admin Access permission set"
  value       = aws_ssoadmin_permission_set.namespace_admins.name
}

output "developers_permission_set_name" {
  description = "Name of the Developer Access permission set"
  value       = aws_ssoadmin_permission_set.developers.name
}

output "auditors_permission_set_name" {
  description = "Name of the Auditor Access permission set"
  value       = aws_ssoadmin_permission_set.auditors.name
}

###############################################################################
# SUMMARY OUTPUTS
###############################################################################

output "user_personas_summary" {
  description = "Summary of all user personas and their Kubernetes RBAC mapping"
  value = {
    administrator = {
      group_id           = aws_identitystore_group.admin.group_id
      permission_set_arn = data.aws_ssoadmin_permission_set.admin.arn
      k8s_role           = "cluster-admin"
      session_duration   = "existing"
      description        = "Full AWS + K8s access for platform owners (existing permission set)"
    }
    platform_engineer = {
      group_id           = aws_identitystore_group.platform_engineers.group_id
      permission_set_arn = aws_ssoadmin_permission_set.platform_engineers.arn
      k8s_role           = "cluster-admin"
      session_duration   = "8 hours"
      description        = "EKS/VPC management, no IAM control"
    }
    namespace_admin = {
      group_id           = aws_identitystore_group.namespace_admins.group_id
      permission_set_arn = aws_ssoadmin_permission_set.namespace_admins.arn
      k8s_role           = "namespace-admin"
      session_duration   = "8 hours"
      description        = "Full namespace control, no cluster resources"
    }
    developer = {
      group_id           = aws_identitystore_group.developers.group_id
      permission_set_arn = aws_ssoadmin_permission_set.developers.arn
      k8s_role           = "developer"
      session_duration   = "12 hours"
      description        = "Deploy apps, limited secrets access"
    }
    auditor = {
      group_id           = aws_identitystore_group.auditors.group_id
      permission_set_arn = aws_ssoadmin_permission_set.auditors.arn
      k8s_role           = "view"
      session_duration   = "12 hours"
      description        = "Read-only for compliance auditing"
    }
  }
}

output "managed_users_summary" {
  description = "Summary of all users managed by this Terraform configuration"
  value = {
    andre_dreyer = {
      user_id      = aws_identitystore_user.andre_dreyer.user_id
      username     = aws_identitystore_user.andre_dreyer.user_name
      display_name = aws_identitystore_user.andre_dreyer.display_name
      email        = "andre.dreyer@datafaced.com"
      groups       = ["Administrators", "Platform-Engineers", "Namespace-Admins", "Developers", "Auditors"]
    }
  }
}
