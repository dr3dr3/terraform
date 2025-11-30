variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Datafaced"
}

variable "tfe_token" {
  description = "Terraform Enterprise/Cloud API token (set via environment variable or credentials file)"
  type        = string
  sensitive   = true
}

variable "github_oauth_token_id" {
  description = "GitHub OAuth token ID for VCS integration (obtained from Terraform Cloud UI)"
  type        = string
  sensitive   = true
}

variable "github_repository_identifier" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "dr3dr3/terraform"
}

variable "vcs_branch" {
  description = "Default VCS branch to use for workspaces"
  type        = string
  default     = "main"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "platform-team"
}

variable "environment" {
  description = "Environment tag for resources"
  type        = string
  default     = "management"
}

variable "managed_by" {
  description = "Managed-by tag for resources"
  type        = string
  default     = "terraform-cloud"
}

variable "layer" {
  description = "Layer tag for resources"
  type        = string
  default     = "foundation"
}

################################################################################
# Auto-Apply Settings per ADR-014
################################################################################
# 
# ADR-014 Trigger Strategy Summary:
# - Foundation (all envs): CLI-driven, Manual apply
# - Application (dev): API/GHA-driven, Auto-apply
# - Application (staging): VCS-driven, Manual apply
# - Application (prod): API/GHA-driven, Manual apply
# - Platform (dev): API/GHA-driven, Auto-apply
# - Platform (sandbox): VCS-driven, Auto-apply
# - Platform (staging/prod): API/GHA-driven, Manual apply
#
################################################################################

variable "auto_apply_dev" {
  description = "Enable auto-apply for development platform/application workspaces (per ADR-014)"
  type        = bool
  default     = true
}

variable "auto_apply_sandbox" {
  description = "Enable auto-apply for sandbox platform workspaces (per ADR-014)"
  type        = bool
  default     = true
}

variable "auto_apply_staging" {
  description = "Enable auto-apply for staging workspaces (per ADR-014: false for applications)"
  type        = bool
  default     = false
}

variable "auto_apply_production" {
  description = "Enable auto-apply for production workspaces (per ADR-014: always false)"
  type        = bool
  default     = false
}

variable "auto_apply_management" {
  description = "Enable auto-apply for management workspaces (per ADR-014: always false for foundation)"
  type        = bool
  default     = false
}

variable "aws_account_id_development" {
  description = "AWS account ID for the development environment"
  type        = string
  default     = "" # Set via terraform.tfvars or TFC variable
}

variable "aws_account_id_staging" {
  description = "AWS account ID for the staging environment"
  type        = string
  default     = "" # Set via terraform.tfvars or TFC variable
}

variable "aws_account_id_production" {
  description = "AWS account ID for the production environment"
  type        = string
  default     = "" # Set via terraform.tfvars or TFC variable
}

variable "aws_account_id_sandbox" {
  description = "AWS account ID for the sandbox environment"
  type        = string
  default     = "" # Set via terraform.tfvars or TFC variable
}
