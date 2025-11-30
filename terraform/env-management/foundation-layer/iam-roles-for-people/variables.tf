###############################################################################
# TAG VARIABLES
###############################################################################

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

###############################################################################
# ACCOUNT CONFIGURATION VARIABLES
###############################################################################

variable "additional_account_ids" {
  description = <<-EOT
    List of all AWS account IDs to assign permission sets to.
    This should include all environment accounts (dev, staging, prod, sandbox).
    Administrators, Platform Engineers, and Auditors get access to ALL these accounts.
  EOT
  type        = list(string)
  default     = []
}

variable "non_production_account_ids" {
  description = <<-EOT
    List of non-production AWS account IDs (dev, staging, sandbox).
    Namespace Admins and Developers only get access to these accounts.
    This implements the principle of least privilege - developers cannot access production.
  EOT
  type        = list(string)
  default     = []
}
