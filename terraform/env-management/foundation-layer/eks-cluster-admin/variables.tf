# =============================================================================
# Variables - EKS 1Password Sync
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform Cloud Configuration
# -----------------------------------------------------------------------------

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Datafaced"
}

# -----------------------------------------------------------------------------
# 1Password Configuration
# -----------------------------------------------------------------------------
# This workspace uses CLI Mode which requires:
# 1. The `op` CLI binary installed locally
# 2. OP_SERVICE_ACCOUNT_TOKEN environment variable set
#
# Run this workspace locally - it does NOT work in TFC standard runners.
# -----------------------------------------------------------------------------

variable "onepassword_vault_name" {
  description = "Name of the 1Password vault to store EKS cluster details"
  type        = string
  default     = "Infrastructure"
}

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where EKS clusters are deployed"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_account_id_development" {
  description = "AWS account ID for the development environment"
  type        = string
  default     = ""
}

variable "aws_account_id_staging" {
  description = "AWS account ID for the staging environment"
  type        = string
  default     = ""
}

variable "aws_account_id_production" {
  description = "AWS account ID for the production environment"
  type        = string
  default     = ""
}

variable "aws_account_id_sandbox" {
  description = "AWS account ID for the sandbox environment"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# EKS Workspace Configuration
# -----------------------------------------------------------------------------

variable "eks_development_workspace" {
  description = "Terraform Cloud workspace name for development EKS cluster"
  type        = string
  default     = "development-platform-eks"
}

variable "eks_staging_workspace" {
  description = "Terraform Cloud workspace name for staging EKS cluster"
  type        = string
  default     = "staging-platform-eks"
}

variable "eks_production_workspace" {
  description = "Terraform Cloud workspace name for production EKS cluster"
  type        = string
  default     = "production-platform-eks"
}

variable "eks_sandbox_workspace" {
  description = "Terraform Cloud workspace name for sandbox EKS cluster"
  type        = string
  default     = "sandbox-platform-eks"
}

# -----------------------------------------------------------------------------
# Sync Toggles
# -----------------------------------------------------------------------------

variable "sync_development_eks" {
  description = "Whether to sync development EKS cluster details to 1Password"
  type        = bool
  default     = true
}

variable "sync_staging_eks" {
  description = "Whether to sync staging EKS cluster details to 1Password"
  type        = bool
  default     = false
}

variable "sync_production_eks" {
  description = "Whether to sync production EKS cluster details to 1Password"
  type        = bool
  default     = false
}

variable "sync_sandbox_eks" {
  description = "Whether to sync sandbox EKS cluster details to 1Password"
  type        = bool
  default     = false
}
