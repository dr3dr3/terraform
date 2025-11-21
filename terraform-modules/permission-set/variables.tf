variable "permission_set_name" {
  description = "Name of the Permission Set"
  type        = string
}

variable "description" {
  description = "Description of the Permission Set"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "layer" {
  description = "Infrastructure layer (foundation, platform, application)"
  type        = string
}

variable "session_duration" {
  description = "Session duration in ISO 8601 format (e.g., PT2H for 2 hours)"
  type        = string
  default     = "PT2H"
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "inline_policy" {
  description = "Inline policy JSON to attach"
  type        = string
  default     = ""
}

variable "account_assignments" {
  description = "Map of account assignments (key is descriptive name)"
  type = map(object({
    principal_id   = string
    principal_type = string # USER or GROUP
    account_id     = string
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}
