# =============================================================================
# Variables - EKS Auto Mode Cluster
# =============================================================================
# REVIEW THESE CAREFULLY - Key decisions are marked with [DECISION REQUIRED]
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Environment name (used in resource naming)"
  type        = string
  default     = "stg"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "Platform-Team"
}

# -----------------------------------------------------------------------------
# VPC Configuration
# [DECISION REQUIRED] - Review CIDR block to avoid conflicts
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = <<-EOT
    [DECISION REQUIRED] CIDR block for the VPC.
    
    Considerations:
    - Must not overlap with other VPCs you plan to peer with
    - /16 provides 65,536 IP addresses
    - Smaller blocks (/18, /20) are possible but limit growth
    
    Common patterns:
    - Development: 10.0.0.0/16
    - Staging:     10.1.0.0/16
    - Production:  10.2.0.0/16
  EOT
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = <<-EOT
    [DECISION REQUIRED] Number of Availability Zones to use.
    
    Considerations:
    - 2 AZs: Lower cost, still provides HA
    - 3 AZs: Best practice, higher availability, more NAT Gateway cost
    
    Cost impact: ~$32/month per additional NAT Gateway
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "AZ count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    [DECISION REQUIRED] Use a single NAT Gateway instead of one per AZ.
    
    Considerations:
    - true:  Lower cost (~$32/month), single point of failure
    - false: Higher cost (~$64/month for 2 AZs), highly available
    
    Recommendation: false for staging (closer to production config)
  EOT
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EKS Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster (will be prefixed with environment)"
  type        = string
  default     = "eks-auto"
}

variable "kubernetes_version" {
  description = <<-EOT
    [DECISION REQUIRED] Kubernetes version for the cluster.
    
    Available versions: 1.28, 1.29, 1.30, 1.31
    
    Considerations:
    - Newer versions have latest features and security patches
    - Check application compatibility before choosing
    - AWS supports versions for ~14 months after release
    
    Recommendation: Use latest (1.31) for new clusters
  EOT
  type        = string
  default     = "1.31"

  validation {
    condition     = contains(["1.28", "1.29", "1.30", "1.31"], var.kubernetes_version)
    error_message = "Kubernetes version must be 1.28, 1.29, 1.30, or 1.31."
  }
}

# -----------------------------------------------------------------------------
# Cluster Access Configuration
# [DECISION REQUIRED] - Security-critical settings
# -----------------------------------------------------------------------------

variable "cluster_endpoint_public_access" {
  description = <<-EOT
    [DECISION REQUIRED] Enable public access to the EKS API endpoint.
    
    Considerations:
    - true:  Can access cluster from anywhere (with auth)
    - false: Must use VPN/bastion/VPC to access cluster
    
    Security implications:
    - Public access is protected by IAM authentication
    - For highest security, disable and use private access only
    - Can combine with CIDR restrictions (see public_access_cidrs)
  EOT
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = <<-EOT
    Enable private access to the EKS API endpoint.
    
    This allows nodes and pods within the VPC to communicate
    with the control plane via the private endpoint.
    
    Recommendation: Always enable this.
  EOT
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = <<-EOT
    [DECISION REQUIRED] CIDR blocks allowed to access public endpoint.
    
    Considerations:
    - ["0.0.0.0/0"]: Allow from anywhere (default, less secure)
    - ["YOUR_IP/32"]: Restrict to specific IPs (more secure)
    
    If you have a static IP or VPN, restrict access here.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Cluster Logging Configuration
# -----------------------------------------------------------------------------

variable "cluster_enabled_log_types" {
  description = <<-EOT
    [DECISION REQUIRED] EKS control plane log types to enable.
    
    Available types:
    - api:               API server logs
    - audit:             Kubernetes audit logs (who did what)
    - authenticator:     Authentication logs
    - controllerManager: Controller manager logs
    - scheduler:         Scheduler logs
    
    Cost: CloudWatch Logs charges apply (~$0.50/GB ingested)
    
    Recommendation:
    - Minimum: ["api", "audit"] for security visibility
    - Full:    All types for comprehensive debugging
  EOT
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_retention_days" {
  description = <<-EOT
    [DECISION REQUIRED] Number of days to retain control plane logs.
    
    Options: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    
    Cost considerations:
    - Longer retention = higher storage costs
    - 60 days is reasonable for staging
    - Production may require 90+ days for compliance
  EOT
  type        = number
  default     = 60

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.cloudwatch_log_retention_days
    )
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "enable_secrets_encryption" {
  description = <<-EOT
    [DECISION REQUIRED] Enable envelope encryption for Kubernetes secrets.
    
    Considerations:
    - true:  Secrets are encrypted at rest with KMS (recommended)
    - false: Secrets stored in etcd without additional encryption
    
    Cost: ~$1/month for KMS key
    
    Recommendation: Always enable for staging (matching production)
  EOT
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# EKS Auto Mode Configuration
# -----------------------------------------------------------------------------

variable "auto_mode_enabled" {
  description = <<-EOT
    Enable EKS Auto Mode for automatic compute management.
    
    Auto Mode automatically:
    - Provisions compute resources based on workload needs
    - Scales nodes up/down
    - Handles node lifecycle and upgrades
    - Optimizes for cost and performance
  EOT
  type        = bool
  default     = true
}

variable "auto_mode_node_pools" {
  description = <<-EOT
    [DECISION REQUIRED] Node pools to enable for Auto Mode.
    
    Available pools:
    - general-purpose: Balanced compute (m5, m6i families)
    - system:          For system workloads (CoreDNS, etc.)
    
    Recommendation: Start with both for full functionality
  EOT
  type        = list(string)
  default     = ["general-purpose", "system"]
}

# -----------------------------------------------------------------------------
# Access Entry Configuration
# -----------------------------------------------------------------------------

variable "enable_cluster_creator_admin_permissions" {
  description = <<-EOT
    Grant the IAM principal creating the cluster admin access.
    
    This is useful for initial setup and debugging.
    Can be disabled after proper RBAC is configured.
  EOT
  type        = bool
  default     = true
}

variable "additional_cluster_admins" {
  description = <<-EOT
    Additional IAM principals to grant cluster admin access.
    
    Format: List of IAM principal ARNs
    Example: ["arn:aws:iam::123456789012:role/AdminRole"]
  EOT
  type        = list(string)
  default     = []
}
