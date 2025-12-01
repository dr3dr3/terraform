# =============================================================================
# EKS Auto Mode Cluster
# =============================================================================
# Creates the EKS cluster with Auto Mode enabled
# Includes OIDC provider for IAM Roles for Service Accounts (IRSA)
# =============================================================================

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Control Plane Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-control-plane-logs"
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  # When EKS Auto Mode is enabled, self-managed addons must be disabled
  bootstrap_self_managed_addons = false

  # VPC configuration
  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Control plane logging
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Secrets encryption with KMS
  dynamic "encryption_config" {
    for_each = var.enable_secrets_encryption ? [1] : []

    content {
      provider {
        key_arn = aws_kms_key.eks_secrets[0].arn
      }
      resources = ["secrets"]
    }
  }

  # EKS Auto Mode configuration
  compute_config {
    enabled       = var.auto_mode_enabled
    node_pools    = var.auto_mode_node_pools
    node_role_arn = aws_iam_role.eks_auto_node.arn
  }

  # Storage configuration for Auto Mode
  storage_config {
    block_storage {
      enabled = var.auto_mode_enabled
    }
  }

  # Kubernetes network configuration
  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "172.20.0.0/16"

    # Elastic Load Balancing for Auto Mode
    elastic_load_balancing {
      enabled = var.auto_mode_enabled
    }
  }

  # Access configuration - use API for access management
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  }

  # Ensure log group exists before cluster
  depends_on = [
    aws_cloudwatch_log_group.eks_cluster,
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_iam_role_policy_attachment.eks_auto_node_worker_policy,
    aws_iam_role_policy_attachment.eks_auto_node_cni_policy,
    aws_iam_role_policy_attachment.eks_auto_node_ecr_readonly,
  ]

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
}

# -----------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# -----------------------------------------------------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-oidc-provider"
  })
}

# -----------------------------------------------------------------------------
# Access Entries for Additional Admins
# -----------------------------------------------------------------------------

resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.additional_cluster_admins)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.additional_cluster_admins)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
