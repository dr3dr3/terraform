terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19"
    }
  }

  # Local backend for testing - uncomment cloud block when ready for Terraform Cloud
  # cloud {
  #   organization = "Datafaced"
  #   workspaces {
  #     name = "development-applications-eks-learning"
  #   }
  # }
}

provider "aws" {
  region = local.region
}

################################################################################
# Local Variables
################################################################################

locals {
  name   = "learning-eks"
  region = "ap-southeast-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = ["${local.region}a"]  # Single AZ for cost savings

  tags = {
    Environment = "learning"
    ManagedBy   = "terraform"
    Project     = "eks-learning"
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true  # Single NAT gateway for cost savings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.8"

  cluster_name    = local.name
  cluster_version = "1.31"  # Latest version as of now

  # Private cluster access only
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster encryption
  cluster_encryption_config = {
    resources        = ["secrets"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # IAM roles for service accounts (IRSA)
  enable_irsa = true

  # Managed node group with spot instances for cost savings
  eks_managed_node_groups = {
    learning = {
      # Use spot instances for significant cost savings
      capacity_type = "SPOT"

      # Minimal configuration for learning
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # Low-cost instance types
      instance_types = ["t3a.medium", "t3.medium"]

      # Disk configuration
      disk_size = 20

      # Labels
      labels = {
        Environment = "learning"
        NodeGroup   = "spot"
      }

      # Update configuration
      update_config = {
        max_unavailable = 1
      }

      # Security
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }

      tags = {
        NodeGroup = "learning-spot"
      }
    }
  }

  # Access entries for IAM principals
  access_entries = {
    # Admin role
    admin = {
      principal_arn = aws_iam_role.eks_admin.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # Read-only role
    readonly = {
      principal_arn = aws_iam_role.eks_readonly.arn

      policy_associations = {
        readonly = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Security group rules
  node_security_group_additional_rules = {
    # Allow nodes to communicate with each other
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    # Allow access from control plane to webhook port
    ingress_cluster_webhook = {
      description                   = "Cluster API to node webhook"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    }

    # Allow pods to communicate with the cluster API server
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = local.tags
}

################################################################################
# IAM Roles for EKS Access
################################################################################

# Admin role for Kubernetes admin access
resource "aws_iam_role" "eks_admin" {
  name = "${local.name}-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.account_id
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-admin-role"
    }
  )
}

# Attach policy for EKS cluster access
resource "aws_iam_role_policy_attachment" "eks_admin_cluster_policy" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Read-only role for console/kubectl access
resource "aws_iam_role" "eks_readonly" {
  name = "${local.name}-readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.account_id
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-readonly-role"
    }
  )
}

# Attach read-only console access policy
resource "aws_iam_role_policy" "eks_readonly_console" {
  name = "eks-readonly-console-policy"
  role = aws_iam_role.eks_readonly.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Supporting Resources
################################################################################

data "aws_caller_identity" "current" {}
