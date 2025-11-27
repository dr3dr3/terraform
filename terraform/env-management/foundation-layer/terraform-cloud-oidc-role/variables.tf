variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-woutheast-2"
}

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "Datafaced"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
}
