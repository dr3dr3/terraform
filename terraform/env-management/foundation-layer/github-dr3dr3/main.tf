###############################################################################
# GITHUB REPOSITORIES MANAGEMENT
###############################################################################
#
# This Terraform configuration manages GitHub repositories for dr3dr3.
# It provides a centralized way to manage:
# - Repository settings (visibility, features, merge options)
# - Branch protection rules and rulesets
# - Repository environments (dev, staging, prod)
# - Repository variables and secrets
# - GitHub Actions permissions
#
# Managed repositories:
# - terraform: Infrastructure as Code with Terraform
# - platform: Platform engineering configurations
# - ai: AI/ML projects and experiments
# - kubernetes: Kubernetes manifests and configurations
# - k8s-homelab-admin: Homelab Kubernetes administration
# - kubestronaut: Kubernetes learning and certification prep
# - rag: Retrieval Augmented Generation projects
# - template-devcontainer: Dev Container template repository
# - dotfiles: Personal dotfiles and shell configurations
# - terraform-modules: Reusable Terraform modules
# - k8s-homelab-manifests: Homelab Kubernetes manifests
#
###############################################################################

locals {
  # Common tags for Terraform Cloud workspace
  common_tags = {
    Owner       = var.owner
    Environment = var.environment
    Layer       = var.layer
    ManagedBy   = var.managed_by
  }

  # Repository definitions with overrides
  # Each repository can override default settings
  repositories = {
    terraform = {
      description = "Infrastructure as Code with Terraform - AWS, Terraform Cloud, and GitHub management"
      topics      = ["terraform", "infrastructure-as-code", "aws", "terraform-cloud", "iac"]
      homepage    = ""
      visibility  = "public"

      # Features
      has_issues      = true
      has_discussions = true
      has_wiki        = false
      has_projects    = true

      # Branch protection
      protected_branches = ["main"]

      # Environments
      environments = ["development", "staging", "production"]
    }

    platform = {
      description = "Platform engineering configurations and tooling"
      topics      = ["platform-engineering", "devops", "infrastructure", "kubernetes"]
      homepage    = ""
      visibility  = "public"

      has_issues   = true
      has_projects = true

      protected_branches = ["main"]
      environments       = ["development", "staging", "production"]
    }

    ai = {
      description = "AI/ML projects, experiments, and learning resources"
      topics      = ["artificial-intelligence", "machine-learning", "python", "llm", "ai"]
      homepage    = ""
      visibility  = "public"

      has_issues      = true
      has_discussions = true

      protected_branches = ["main"]
      environments       = []
    }

    kubernetes = {
      description = "Kubernetes manifests, configurations, and learning resources"
      topics      = ["kubernetes", "k8s", "containers", "cloud-native", "devops"]
      homepage    = ""
      visibility  = "public"

      has_issues = true

      protected_branches = ["main"]
      environments       = ["development", "staging", "production"]
    }

    "k8s-homelab-admin" = {
      description = "Kubernetes homelab administration and cluster management"
      topics      = ["kubernetes", "homelab", "k8s", "self-hosted", "infrastructure"]
      homepage    = ""
      visibility  = "public"

      has_issues = true
      has_wiki   = true

      protected_branches = ["main"]
      environments       = ["homelab"]
    }

    kubestronaut = {
      description = "Kubernetes certification preparation and learning resources (CKA, CKAD, CKS)"
      topics      = ["kubernetes", "certification", "cka", "ckad", "cks", "learning"]
      homepage    = ""
      visibility  = "public"

      has_issues      = true
      has_discussions = true

      protected_branches = ["main"]
      environments       = []
    }

    rag = {
      description = "Retrieval Augmented Generation (RAG) projects and experiments"
      topics      = ["rag", "llm", "vector-database", "ai", "python", "langchain"]
      homepage    = ""
      visibility  = "public"

      has_issues = true

      protected_branches = ["main"]
      environments       = []
    }

    "template-devcontainer" = {
      description = "Template repository for VS Code Dev Containers"
      topics      = ["devcontainer", "template", "vscode", "docker", "development-environment"]
      homepage    = ""
      visibility  = "public"

      is_template = true
      has_issues  = true

      protected_branches = ["main"]
      environments       = []
    }

    dotfiles = {
      description = "Personal dotfiles, shell configurations, and development environment setup"
      topics      = ["dotfiles", "shell", "fish", "neovim", "configuration"]
      homepage    = ""
      visibility  = "public"

      has_issues = true

      protected_branches = ["main"]
      environments       = []
    }

    "terraform-modules" = {
      description = "Reusable Terraform modules for AWS, Kubernetes, and GitHub"
      topics      = ["terraform", "terraform-modules", "aws", "infrastructure-as-code", "reusable"]
      homepage    = ""
      visibility  = "public"

      has_issues      = true
      has_discussions = true

      protected_branches = ["main"]
      environments       = []
    }

    "k8s-homelab-manifests" = {
      description = "Kubernetes manifests for homelab deployments"
      topics      = ["kubernetes", "homelab", "manifests", "gitops", "argocd"]
      homepage    = ""
      visibility  = "public"

      has_issues = true

      protected_branches = ["main"]
      environments       = ["homelab"]
    }
  }
}
