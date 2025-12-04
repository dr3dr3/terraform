# =============================================================================
# IAM Roles for EKS
# =============================================================================
# Creates the IAM roles required by EKS:
# - Cluster role: Allows EKS to manage AWS resources
# - Auto Mode role: Allows EKS Auto Mode to manage compute
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    sid     = "EKSClusterAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# VPC Resource Controller policy - required for security groups for pods
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# -----------------------------------------------------------------------------
# EKS Auto Mode Node IAM Role
# Required for Auto Mode to manage EC2 instances
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_auto_node_assume_role" {
  statement {
    sid     = "EKSAutoNodeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_auto_node" {
  name               = "${local.cluster_name}-auto-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_auto_node_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-auto-node-role"
  })
}

# Required policies for EKS Auto Mode nodes
resource "aws_iam_role_policy_attachment" "eks_auto_node_worker_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_auto_node.name
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_cni_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_auto_node.name
}

resource "aws_iam_role_policy_attachment" "eks_auto_node_ecr_readonly" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_auto_node.name
}

# SSM policy for node debugging (optional but recommended)
resource "aws_iam_role_policy_attachment" "eks_auto_node_ssm" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_auto_node.name
}
