variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production"
  }
}

variable "layer" {
  description = "Infrastructure layer (foundation, platform, application)"
  type        = string
  validation {
    condition     = contains(["foundation", "platform", "application"], var.layer)
    error_message = "Layer must be one of: foundation, platform, application"
  }
}

variable "context" {
  description = "Execution context (cicd or human)"
  type        = string
  validation {
    condition     = contains(["cicd", "human"], var.context)
    error_message = "Context must be either 'cicd' or 'human'"
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

variable "oidc_audience" {
  description = "Expected audience for OIDC tokens"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "cicd_subject_claim" {
  description = "Subject claim for CICD context (e.g., repo:org/repo:ref:refs/heads/main)"
  type        = string
  default     = ""
}

variable "human_subject_pattern" {
  description = "Subject pattern for human context (e.g., repo:org/repo:*)"
  type        = string
  default     = ""
}

variable "session_duration" {
  description = "Maximum session duration in seconds"
  type        = number
  default     = 3600
  validation {
    condition     = var.session_duration >= 3600 && var.session_duration <= 43200
    error_message = "Session duration must be between 3600 (1 hour) and 43200 (12 hours)"
  }
}

variable "permission_boundary_arn" {
  description = "ARN of the permission boundary to attach to the role"
  type        = string
  default     = null
}

variable "attach_readonly_policy" {
  description = "Whether to attach AWS ReadOnlyAccess managed policy"
  type        = bool
  default     = true
}

variable "custom_policy_json" {
  description = "Custom IAM policy JSON for Terraform operations"
  type        = string
}

variable "additional_policy_arns" {
  description = "List of additional managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to the role"
  type        = map(string)
  default     = {}
}
