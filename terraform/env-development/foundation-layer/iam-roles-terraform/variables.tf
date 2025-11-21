variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider in this AWS account"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
  default     = "token.actions.githubusercontent.com"
}

variable "oidc_audience" {
  description = "Expected audience for OIDC tokens"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "permission_boundary_arn" {
  description = "ARN of the permission boundary policy"
  type        = string
  default     = null
}

variable "foundation_account_assignments" {
  description = "Account assignments for Foundation Permission Set"
  type = map(object({
    principal_id   = string
    principal_type = string
    account_id     = string
  }))
  default = {}
}

variable "platform_account_assignments" {
  description = "Account assignments for Platform Permission Set"
  type = map(object({
    principal_id   = string
    principal_type = string
    account_id     = string
  }))
  default = {}
}

variable "application_account_assignments" {
  description = "Account assignments for Application Permission Set"
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
