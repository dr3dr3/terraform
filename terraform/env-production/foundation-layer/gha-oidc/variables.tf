# =============================================================================
# Variables for GitHub Actions OIDC Role - Production Account
# =============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository"
  type        = string
  default     = "dr3dr3"
}

variable "github_repo" {
  description = "GitHub repository name for the Terraform code"
  type        = string
  default     = "terraform"
}

variable "session_duration" {
  description = "Maximum session duration in seconds (1-12 hours)"
  type        = number
  default     = 7200 # 2 hours (matches iam-roles-for-terraform)

  validation {
    condition     = var.session_duration >= 3600 && var.session_duration <= 43200
    error_message = "Session duration must be between 3600 (1 hour) and 43200 (12 hours)"
  }
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "Andre Dreyer"
}
