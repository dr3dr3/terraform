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

variable "additional_account_ids" {
  description = "List of additional AWS account IDs to assign permission sets to (e.g., dev, staging, prod accounts)"
  type        = list(string)
  default     = []
}
