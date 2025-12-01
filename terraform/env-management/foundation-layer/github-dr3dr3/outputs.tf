###############################################################################
# OUTPUTS
###############################################################################

output "repositories" {
  description = "Map of all managed repositories with their details"
  value = {
    for name, repo in github_repository.repos : name => {
      id               = repo.id
      name             = repo.name
      full_name        = repo.full_name
      html_url         = repo.html_url
      ssh_clone_url    = repo.ssh_clone_url
      git_clone_url    = repo.git_clone_url
      visibility       = repo.visibility
      default_branch   = repo.default_branch
      topics           = repo.topics
      has_issues       = repo.has_issues
      has_projects     = repo.has_projects
      has_wiki         = repo.has_wiki
      has_discussions  = repo.has_discussions
    }
  }
}

output "repository_names" {
  description = "List of all managed repository names"
  value       = [for name, _ in github_repository.repos : name]
}

output "repository_urls" {
  description = "Map of repository names to their HTML URLs"
  value = {
    for name, repo in github_repository.repos : name => repo.html_url
  }
}

output "repository_count" {
  description = "Number of repositories managed"
  value       = length(github_repository.repos)
}

output "environments" {
  description = "Map of all repository environments"
  value = {
    for key, env in github_repository_environment.envs : key => {
      repository  = env.repository
      environment = env.environment
    }
  }
}

output "protected_branches" {
  description = "Map of repositories with protected branches"
  value = {
    for name, ruleset in github_repository_ruleset.main_branch : name => {
      repository  = ruleset.repository
      ruleset_id  = ruleset.id
      enforcement = ruleset.enforcement
    }
  }
}
