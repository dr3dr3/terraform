# =============================================================================
# dotai MCP Server - Production
# =============================================================================
# Provisions ECR, Lambda (container image), Function URL, IAM, and SSM for
# the dotai personal MCP server in the production AWS account.
# =============================================================================

terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

locals {
  name = "dotai${var.environment_suffix}"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Owner       = var.owner
      Project     = "dotai-mcp"
      Environment = "Production"
      Repository  = "dr3dr3/dotai-mcp"
    }
  }
}
