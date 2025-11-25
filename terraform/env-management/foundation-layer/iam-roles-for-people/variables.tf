variable "owner" {
  description = "Owner tag for resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag for resources"
  type        = string
  default     = "engineering"
}

variable "additional_account_ids" {
  description = "List of additional AWS account IDs to assign permission sets to (e.g., dev, staging, prod accounts)"
  type        = list(string)
  default     = []
}
