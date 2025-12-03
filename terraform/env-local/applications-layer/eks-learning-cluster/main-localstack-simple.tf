terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19"
    }
  }
}

# Provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1" # Match LocalStack default region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # LocalStack endpoints
  endpoints {
    ec2 = "http://localhost:4566"
    eks = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

################################################################################
# Local Variables
################################################################################

locals {
  name = "learning-eks"

  tags = {
    Environment = "learning"
    ManagedBy   = "terraform"
    Project     = "eks-learning-localstack"
  }
}

################################################################################
# VPC Resources (without module)
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-vpc"
    }
  )
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # LocalStack typically uses us-east-1a

  tags = merge(
    local.tags,
    {
      Name                              = "${local.name}-private-subnet"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(
    local.tags,
    {
      Name                     = "${local.name}-public-subnet"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-igw"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "cluster" {
  name        = "${local.name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-cluster-sg"
    }
  )
}

resource "aws_security_group" "node" {
  name        = "${local.name}-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Allow pods to communicate with the cluster API Server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-node-sg"
    }
  )
}

################################################################################
# IAM Roles
################################################################################

# EKS Cluster Role
resource "aws_iam_role" "cluster" {
  name = "${local.name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-cluster-role"
    }
  )
}

# Attach basic EKS cluster policy (may not exist in LocalStack)
# Commenting out to avoid potential errors with LocalStack
# resource "aws_iam_role_policy_attachment" "cluster_policy" {
#   role       = aws_iam_role.cluster.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# }

# Basic inline policy for cluster
resource "aws_iam_role_policy" "cluster_policy" {
  name = "${local.name}-cluster-policy"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# EKS Node Role
resource "aws_iam_role" "node" {
  name = "${local.name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-node-role"
    }
  )
}

# Basic inline policy for nodes
resource "aws_iam_role_policy" "node_policy" {
  name = "${local.name}-node-policy"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecr:*",
          "eks:*"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# EKS Cluster (Minimal Configuration)
################################################################################

resource "aws_eks_cluster" "main" {
  name     = local.name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = [aws_subnet.private.id, aws_subnet.public.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Remove encryption config for LocalStack compatibility
  # cluster_encryption_config {
  #   resources = ["secrets"]
  # }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy.cluster_policy
  ]
}

################################################################################
# EKS Node Group (Minimal Configuration)
################################################################################

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodegroup"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.private.id]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Use standard instance type (LocalStack may not distinguish between types)
  instance_types = ["t3.medium"]

  # Remove capacity_type for LocalStack (may not support SPOT)
  # capacity_type = "SPOT"

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-nodegroup"
    }
  )

  depends_on = [
    aws_iam_role_policy.node_policy
  ]
}

################################################################################
# Outputs
################################################################################

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}
