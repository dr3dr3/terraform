variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Datafaced"
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
  default     = "Platform-Team"
}

variable "cost_center" {
  description = "Cost center tag for resources"
  type        = string
  default     = "Infrastructure"
}

variable "auto_apply_dev" {
  description = "Enable auto-apply for development workspaces"
  type        = bool
  default     = true
}

variable "auto_apply_sandbox" {
  description = "Enable auto-apply for sandbox workspaces"
  type        = bool
  default     = true
}

variable "auto_apply_management" {
  description = "Enable auto-apply for management workspaces"
  type        = bool
  default     = false
}
