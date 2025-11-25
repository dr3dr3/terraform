variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "tfc_project_dev" {
  description = "Terraform Cloud project name for dev environment"
  type        = string
  default     = "development"
}

variable "tfc_project_staging" {
  description = "Terraform Cloud project name for staging environment"
  type        = string
  default     = "staging"
}

variable "tfc_project_prod" {
  description = "Terraform Cloud project name for production environment"
  type        = string
  default     = "production"
}

variable "tfc_workspace_dev_foundation" {
  description = "Terraform Cloud workspace name for dev foundation layer"
  type        = string
  default     = "dev-foundation-layer"
}

variable "tfc_workspace_staging_foundation" {
  description = "Terraform Cloud workspace name for staging foundation layer"
  type        = string
  default     = "staging-foundation-layer"
}

variable "tfc_workspace_prod_foundation" {
  description = "Terraform Cloud workspace name for production foundation layer"
  type        = string
  default     = "prod-foundation-layer"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag for resources"
  type        = string
  default     = "engineering"
}
