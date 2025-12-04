# =============================================================================
# EKS Auto Mode Cluster - Staging Platform Layer
# =============================================================================
# This configuration creates an EKS Auto Mode cluster with:
# - Dedicated VPC with public/private subnets across multiple AZs
# - NAT Gateways for private subnet internet access
# - KMS encryption for Kubernetes secrets
# - Control plane logging enabled
# - OIDC provider for IAM Roles for Service Accounts (IRSA)
# =============================================================================

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Staging"
      ManagedBy   = "Terraform"
      Layer       = "platform"
      Owner       = var.owner
      Project     = "eks-auto-mode"
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  # Exclude local zones and wavelength zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  region       = var.aws_region
  cluster_name = "${var.environment}-${var.cluster_name}"

  # Use specified number of AZs
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Subnet CIDR calculations
  # Public subnets: 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
  # Private subnets: 10.1.11.0/24, 10.1.12.0/24, 10.1.13.0/24
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 11)]

  common_tags = {
    Cluster = local.cluster_name
  }
}
