###############################################################################
# GITHUB REPOSITORIES
###############################################################################
#
# Creates and manages GitHub repositories based on the definitions in main.tf
#
###############################################################################

resource "github_repository" "repos" {
  for_each = local.repositories

  name         = each.key
  description  = each.value.description
  visibility   = lookup(each.value, "visibility", var.default_visibility)
  homepage_url = lookup(each.value, "homepage", null)
  topics       = lookup(each.value, "topics", [])

  # Features
  has_issues      = lookup(each.value, "has_issues", var.default_has_issues)
  has_projects    = lookup(each.value, "has_projects", var.default_has_projects)
  has_wiki        = lookup(each.value, "has_wiki", var.default_has_wiki)
  has_downloads   = lookup(each.value, "has_downloads", var.default_has_downloads)
  has_discussions = lookup(each.value, "has_discussions", var.default_has_discussions)

  # Template settings
  is_template = lookup(each.value, "is_template", false)

  # Merge settings
  allow_merge_commit     = lookup(each.value, "allow_merge_commit", var.default_allow_merge_commit)
  allow_squash_merge     = lookup(each.value, "allow_squash_merge", var.default_allow_squash_merge)
  allow_rebase_merge     = lookup(each.value, "allow_rebase_merge", var.default_allow_rebase_merge)
  allow_auto_merge       = lookup(each.value, "allow_auto_merge", var.default_allow_auto_merge)
  delete_branch_on_merge = lookup(each.value, "delete_branch_on_merge", var.default_delete_branch_on_merge)
  allow_update_branch    = lookup(each.value, "allow_update_branch", var.default_allow_update_branch)

  # Security
  vulnerability_alerts = lookup(each.value, "vulnerability_alerts", var.default_vulnerability_alerts)

  # Lifecycle
  archive_on_destroy = lookup(each.value, "archive_on_destroy", var.default_archive_on_destroy)

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

###############################################################################
# BRANCH PROTECTION RULESETS
###############################################################################
#
# Uses the newer GitHub Rulesets API (github_repository_ruleset) instead of
# the deprecated branch protection API. Rulesets provide more flexibility
# and can be applied at organization level.
#
###############################################################################

# Create a ruleset for each repository that has protected branches
resource "github_repository_ruleset" "main_branch" {
  for_each = {
    for name, repo in local.repositories : name => repo
    if length(lookup(repo, "protected_branches", [])) > 0
  }

  name        = "main-branch-protection"
  repository  = github_repository.repos[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = [for branch in each.value.protected_branches : "refs/heads/${branch}"]
      exclude = []
    }
  }

  rules {
    # Require pull request before merging
    pull_request {
      required_approving_review_count   = var.required_approving_review_count
      dismiss_stale_reviews_on_push     = var.dismiss_stale_reviews
      require_code_owner_review         = var.require_code_owner_reviews
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }

    # Require status checks to pass
    # Note: Uncomment and configure when you have CI checks
    # required_status_checks {
    #   required_check {
    #     context = "ci"
    #   }
    #   strict_required_status_checks_policy = true
    # }

    # Require linear history (no merge commits on protected branch)
    # Uncomment if you prefer a linear git history
    # required_linear_history = true

    # Prevent force pushes
    non_fast_forward = true

    # Prevent branch deletion
    deletion = true
  }

  # Bypass actors - add if needed
  # bypass_actors {
  #   actor_id    = 1 # GitHub App ID or user/team ID
  #   actor_type  = "Integration"
  #   bypass_mode = "always"
  # }
}

###############################################################################
# REPOSITORY ENVIRONMENTS
###############################################################################
#
# Creates deployment environments for repositories that need them.
# Environments can have protection rules, secrets, and variables.
#
###############################################################################

# Flatten the environments across all repositories
locals {
  repo_environments = flatten([
    for repo_name, repo in local.repositories : [
      for env_name in lookup(repo, "environments", []) : {
        repo_name = repo_name
        env_name  = env_name
      }
    ]
  ])
}

resource "github_repository_environment" "envs" {
  for_each = {
    for env in local.repo_environments : "${env.repo_name}-${env.env_name}" => env
  }

  repository  = github_repository.repos[each.value.repo_name].name
  environment = each.value.env_name

  # Environment protection rules
  # Uncomment to add reviewers for production environments
  # reviewers {
  #   users = []
  #   teams = []
  # }

  # Deployment branch policy
  deployment_branch_policy {
    protected_branches     = each.value.env_name == "production" ? true : false
    custom_branch_policies = each.value.env_name != "production" ? true : false
  }

  # Wait timer for production (in minutes)
  # Uncomment to add a wait timer before deployments
  # wait_timer = each.value.env_name == "production" ? 30 : 0
}

###############################################################################
# REPOSITORY SECRETS (Placeholder)
###############################################################################
#
# Example structure for managing repository secrets.
# Secrets should be provided via Terraform Cloud workspace variables.
# DO NOT store secrets in plain text in this file!
#
###############################################################################

# Placeholder for repository-level secrets
# Uncomment and configure when ready to manage secrets
#
# resource "github_actions_secret" "example" {
#   for_each = {
#     for secret in var.repository_secrets : "${secret.repo}-${secret.name}" => secret
#   }
#
#   repository      = each.value.repo
#   secret_name     = each.value.name
#   plaintext_value = each.value.value
# }

###############################################################################
# REPOSITORY VARIABLES (Placeholder)
###############################################################################
#
# Example structure for managing repository variables.
# Variables are not sensitive and can be stored in configuration.
#
###############################################################################

# Placeholder for repository-level variables
# Uncomment and configure when ready to manage variables
#
# resource "github_actions_variable" "example" {
#   for_each = {
#     for var in local.repository_variables : "${var.repo}-${var.name}" => var
#   }
#
#   repository    = each.value.repo
#   variable_name = each.value.name
#   value         = each.value.value
# }

###############################################################################
# ENVIRONMENT SECRETS (Placeholder)
###############################################################################
#
# Example structure for managing environment-specific secrets.
#
###############################################################################

# Placeholder for environment-level secrets
# Uncomment and configure when ready
#
# resource "github_actions_environment_secret" "example" {
#   for_each = {
#     for secret in var.environment_secrets : "${secret.repo}-${secret.env}-${secret.name}" => secret
#   }
#
#   repository      = each.value.repo
#   environment     = each.value.env
#   secret_name     = each.value.name
#   plaintext_value = each.value.value
# }

###############################################################################
# ENVIRONMENT VARIABLES (Placeholder)
###############################################################################
#
# Example structure for managing environment-specific variables.
#
###############################################################################

# Placeholder for environment-level variables
# Uncomment and configure when ready
#
# resource "github_actions_environment_variable" "example" {
#   for_each = {
#     for var in local.environment_variables : "${var.repo}-${var.env}-${var.name}" => var
#   }
#
#   repository    = each.value.repo
#   environment   = each.value.env
#   variable_name = each.value.name
#   value         = each.value.value
# }
