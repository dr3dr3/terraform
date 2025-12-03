# Copilot Prompt: Commit Changes and Create PR

Use this prompt when you're ready to commit your changes and create a Pull Request.

## Quick Start

Just say: **"Commit my changes and create a PR"**

Or be more specific:

- "Review my changes, commit them, and open a PR"
- "Create a PR for my terraform changes"
- "Push my changes and create a pull request"

## What This Does

1. **Reviews** all uncommitted changes (staged and unstaged)
2. **Creates** a short-lived feature branch with a descriptive name
3. **Commits** with a conventional commit message
4. **Pushes** to the remote repository
5. **Creates** a Pull Request ready for your review

## Workflow

```text
┌─────────────────┐
│  Your Changes   │
│  (uncommitted)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Review & Diff  │
│  git status/diff│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Create Branch  │
│  feat/fix/etc   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Stage & Commit │
│  git add/commit │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Push & PR     │
│  gh pr create   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Ready for      │
│  Your Review!   │
└─────────────────┘
```

## Branch Naming Convention

| Change Type | Branch Prefix | Example |
|-------------|---------------|---------|
| New feature | `feat/` | `feat/add-eks-cluster` |
| Bug fix | `fix/` | `fix/iam-role-arn` |
| Refactoring | `refactor/` | `refactor/folder-structure` |
| Documentation | `docs/` | `docs/update-readme` |
| Maintenance | `chore/` | `chore/update-providers` |
| Tests | `test/` | `test/add-validation` |

## Commit Message Format

Uses [Conventional Commits](https://www.conventionalcommits.org/):

```text
type: concise description

Examples:
- feat: add EKS workspace for development environment
- fix: correct OIDC provider trust policy
- refactor: align folder names with TFC workspaces
- docs: add bootstrapping guide
- chore: update terraform to 1.14.0
```

## After PR Creation

1. **Review the PR** in GitHub
2. **Approve and merge** when satisfied
3. Branch is **auto-deleted** after merge

## Requirements

- GitHub CLI (`gh`) must be authenticated
- Git must be configured with your credentials
- You must have push access to the repository
