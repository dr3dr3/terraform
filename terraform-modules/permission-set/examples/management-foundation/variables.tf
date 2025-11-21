variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "sandbox_account_assignments" {
  description = "Account assignments for Sandbox Permission Set"
  type = map(object({
    principal_id   = string
    principal_type = string
    account_id     = string
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
