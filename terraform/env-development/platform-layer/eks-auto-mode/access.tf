# ==============================================================================
# EKS Access Entries Configuration
# ==============================================================================
# 
# This file configures AWS IAM principals (SSO roles) that can access the EKS
# cluster via kubectl. It implements the access control model defined in:
# - ADR-016: EKS Cluster Credentials and Cross-Repository Access Strategy
# - ADR-015: User Personas AWS SSO EKS
#
# Access is granted through EKS Access Entries, which map IAM principals to
# Kubernetes permissions using AWS-managed access policies.
#
# AWS EKS Access Policy Reference:
# - AmazonEKSClusterAdminPolicy: Full cluster admin (all resources)
# - AmazonEKSAdminPolicy: Full admin within namespace
# - AmazonEKSEditPolicy: Create/modify resources (no RBAC/secrets)
# - AmazonEKSViewPolicy: Read-only access
#
# Access Scope Types:
# - cluster: Policy applies to entire cluster
# - namespace: Policy applies only to specified namespaces
#
# Development Environment Configuration:
# - Administrators: Full cluster admin access
# - Platform Engineers: Full Kubernetes access (no IAM)
# - Developers: Edit access to dev and default namespaces
#
# NOTE: EKS Access Entries require exact role ARNs (wildcards not supported).
#       We use data sources to dynamically fetch the SSO role ARNs.
#
# ==============================================================================

# -----------------------------------------------------------------------------
# Data Sources - Fetch SSO Role ARNs
# -----------------------------------------------------------------------------
# AWS SSO creates roles with random suffixes (e.g., _f2797e9b77c9c51a)
# We need to fetch the exact ARN for each role using data sources

data "aws_iam_roles" "sso_roles" {
  name_regex  = "AWSReservedSSO_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  # Extract exact role ARNs by matching role name patterns
  admin_role_arn = [
    for arn in data.aws_iam_roles.sso_roles.arns :
    arn if length(regexall("AWSReservedSSO_AdministratorAccess_", arn)) > 0
  ][0]

  platform_engineer_role_arn = [
    for arn in data.aws_iam_roles.sso_roles.arns :
    arn if length(regexall("AWSReservedSSO_PlatformEngineerAccess_", arn)) > 0
  ][0]

  developer_role_arn = [
    for arn in data.aws_iam_roles.sso_roles.arns :
    arn if length(regexall("AWSReservedSSO_DeveloperAccess_", arn)) > 0
  ][0]
}

# -----------------------------------------------------------------------------
# Administrator Access Entry
# -----------------------------------------------------------------------------
# Maps AWS SSO AdministratorAccess role to full EKS cluster admin
# 
# User Persona: admin-user (Administrators group)
# Kubernetes Permission: Full cluster admin (system:masters)
# Use Case: Initial setup, break-glass scenarios, full AWS + K8s access

resource "aws_eks_access_entry" "sso_admins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.admin_role_arn
  type          = "STANDARD"

  tags = merge(local.common_tags, {
    Name     = "${local.cluster_name}-sso-admins"
    UserRole = "Administrator"
  })
}

resource "aws_eks_access_policy_association" "sso_admins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.sso_admins.principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso_admins]
}

# -----------------------------------------------------------------------------
# Platform Engineer Access Entry
# -----------------------------------------------------------------------------
# Maps AWS SSO PlatformEngineerAccess role to full EKS cluster admin
# 
# User Persona: platform-user (Platform-Engineers group)
# Kubernetes Permission: Full cluster access (system:masters)
# Use Case: EKS/infrastructure management, cannot modify IAM
# Note: This is the primary role for day-to-day cluster management

resource "aws_eks_access_entry" "sso_platform_engineers" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.platform_engineer_role_arn
  type          = "STANDARD"

  tags = merge(local.common_tags, {
    Name     = "${local.cluster_name}-sso-platform-engineers"
    UserRole = "PlatformEngineer"
  })
}

resource "aws_eks_access_policy_association" "sso_platform_engineers" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.sso_platform_engineers.principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sso_platform_engineers]
}

# -----------------------------------------------------------------------------
# Developer Access Entry
# -----------------------------------------------------------------------------
# Maps AWS SSO DeveloperAccess role to namespace-scoped edit access
# 
# User Persona: dev-user (Developers group)
# Kubernetes Permission: Can deploy pods, view logs, limited to specific namespaces
# Use Case: Application deployment, cannot access secrets directly
# Namespaces: dev, default

resource "aws_eks_access_entry" "sso_developers" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.developer_role_arn
  type          = "STANDARD"

  tags = merge(local.common_tags, {
    Name     = "${local.cluster_name}-sso-developers"
    UserRole = "Developer"
  })
}

resource "aws_eks_access_policy_association" "sso_developers" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.sso_developers.principal_arn
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["dev", "default"]
  }

  depends_on = [aws_eks_access_entry.sso_developers]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "access_entry_principals" {
  description = "IAM principals granted access to the EKS cluster"
  value = {
    administrators     = local.admin_role_arn
    platform_engineers = local.platform_engineer_role_arn
    developers         = local.developer_role_arn
  }
}
