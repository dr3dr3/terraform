###############################################################################
# IMPORT BLOCKS FOR EXISTING GITHUB REPOSITORIES
###############################################################################
#
# These import blocks are used to import existing GitHub repositories into
# Terraform state. Delete this file after the first successful apply.
#
###############################################################################

import {
  to = github_repository.repos["terraform"]
  id = "terraform"
}

import {
  to = github_repository.repos["platform"]
  id = "platform"
}

import {
  to = github_repository.repos["ai"]
  id = "ai"
}

import {
  to = github_repository.repos["kubernetes"]
  id = "kubernetes"
}

import {
  to = github_repository.repos["k8s-homelab-admin"]
  id = "k8s-homelab-admin"
}

import {
  to = github_repository.repos["kubestronaut"]
  id = "kubestronaut"
}

import {
  to = github_repository.repos["rag"]
  id = "rag"
}

import {
  to = github_repository.repos["template-devcontainer"]
  id = "template-devcontainer"
}

import {
  to = github_repository.repos["dotfiles"]
  id = "dotfiles"
}

import {
  to = github_repository.repos["terraform-modules"]
  id = "terraform-modules"
}

import {
  to = github_repository.repos["k8s-homelab-manifests"]
  id = "k8s-homelab-manifests"
}
