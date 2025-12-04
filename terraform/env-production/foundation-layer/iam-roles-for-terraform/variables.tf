variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Datafaced"
}

variable "tfc_project_prod" {
  description = "Terraform Cloud project name for production environment"
  type        = string
  default     = "aws-production"
}

variable "management_account_id" {
  description = "AWS account ID of the management account (where TFC OIDC provider exists)"
  type        = string
  default     = "169506999567"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "Andre Dreyer"
}
