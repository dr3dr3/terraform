###############################################################################
# GITHUB CONFIGURATION
###############################################################################

variable "github_owner" {
  description = "GitHub account owner (username or organization)"
  type        = string
  default     = "dr3dr3"
}

###############################################################################
# DEFAULT REPOSITORY SETTINGS
###############################################################################

variable "default_visibility" {
  description = "Default visibility for repositories (public or private)"
  type        = string
  default     = "public"
}

variable "default_has_issues" {
  description = "Enable issues for repositories by default"
  type        = bool
  default     = true
}

variable "default_has_projects" {
  description = "Enable projects for repositories by default"
  type        = bool
  default     = false
}

variable "default_has_wiki" {
  description = "Enable wiki for repositories by default"
  type        = bool
  default     = false
}

variable "default_has_downloads" {
  description = "Enable downloads for repositories by default"
  type        = bool
  default     = false
}

variable "default_has_discussions" {
  description = "Enable discussions for repositories by default"
  type        = bool
  default     = false
}

variable "default_allow_merge_commit" {
  description = "Allow merge commits for PRs by default"
  type        = bool
  default     = true
}

variable "default_allow_squash_merge" {
  description = "Allow squash merging for PRs by default"
  type        = bool
  default     = true
}

variable "default_allow_rebase_merge" {
  description = "Allow rebase merging for PRs by default"
  type        = bool
  default     = true
}

variable "default_allow_auto_merge" {
  description = "Allow auto-merge for PRs by default"
  type        = bool
  default     = true
}

variable "default_delete_branch_on_merge" {
  description = "Delete head branches after merge by default"
  type        = bool
  default     = true
}

variable "default_allow_update_branch" {
  description = "Allow updating PR branches by default"
  type        = bool
  default     = true
}

variable "default_vulnerability_alerts" {
  description = "Enable vulnerability alerts by default"
  type        = bool
  default     = true
}

variable "default_archive_on_destroy" {
  description = "Archive repositories instead of deleting when destroyed"
  type        = bool
  default     = true
}

###############################################################################
# BRANCH PROTECTION SETTINGS
###############################################################################

variable "default_branch" {
  description = "Default branch name for repositories"
  type        = string
  default     = "main"
}

variable "enforce_admins" {
  description = "Enforce branch protection rules for admins"
  type        = bool
  default     = false
}

variable "required_approving_review_count" {
  description = "Number of required approving reviews for PRs"
  type        = number
  default     = 1
}

variable "dismiss_stale_reviews" {
  description = "Dismiss stale reviews when new commits are pushed"
  type        = bool
  default     = true
}

variable "require_code_owner_reviews" {
  description = "Require code owner reviews for PRs"
  type        = bool
  default     = false
}

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
