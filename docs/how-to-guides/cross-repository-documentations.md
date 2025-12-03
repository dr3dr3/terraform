# Cross-Repository Documentation & Layered AI Context

A practical guide for managing documentation across multiple Git repositories while providing effective context for AI coding assistants.

## Overview

When working with multiple repositories, documentation often needs to serve two purposes: providing context for humans navigating the codebase, and providing context for AI assistants helping with development. This guide establishes patterns for both, using a central "platform" repository as the single source of truth.

## Architecture

```bash
┌───────────────────────────────────────────────────────────┐
│                     Platform Repository                   │
│                  (Single Source of Truth)                 │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Architecture │  │ Git Strategy │  │  Standards   │     │
│  │   Decisions  │  │   & Workflow │  │  & Patterns  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                           │
└───────────────────────────────────────────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │   Repo A    │    │   Repo B    │    │   Repo C    │
    │             │    │             │    │             │
    │ - Local docs│    │ - Local docs│    │ - Local docs│
    │ - AI context│    │ - AI context│    │ - AI context│
    │ - Synced    │    │ - Synced    │    │ - Synced    │
    │   shared    │    │   shared    │    │   shared    │
    │   docs      │    │   docs      │    │   docs      │
    └─────────────┘    └─────────────┘    └─────────────┘
```

## Documentation Categories

Understanding what belongs where is crucial for maintainability.

### Platform Repository (Centralised)

Documentation that applies across all repositories belongs here:

- **Architecture Decision Records (ADRs)**: Cross-cutting technical decisions
- **Git workflow and branching strategy**: How all repos manage branches, commits, releases
- **Coding standards and conventions**: Language-agnostic principles, naming conventions
- **Security policies**: Authentication patterns, secrets management, vulnerability handling
- **CI/CD patterns**: Pipeline templates, deployment strategies
- **Development environment setup**: Tooling requirements, IDE configurations
- **Contributing guidelines**: PR processes, review standards, communication norms

### Individual Repositories (Local)

Documentation specific to that repository:

- **README.md**: Project-specific overview, quick start, local development
- **API documentation**: Endpoints, schemas, examples specific to this service
- **Data models**: Entity relationships, database schemas
- **Local architecture**: How this specific service is structured
- **Dependencies**: Why specific libraries were chosen for this project
- **Testing**: Project-specific test patterns and fixtures

### Synced Documentation (Cloned from Platform)

High-frequency reference docs that benefit from local availability:

- **Git branching quick reference**: Daily-use commands and workflows
- **Commit message conventions**: Format, scope, types
- **PR checklist**: Standard items to verify before requesting review
- **Code review guidelines**: What reviewers should check

## Pattern 1: Reference Links (Point to Platform)

For documentation that provides context but isn't needed every commit, use links.

### Implementation

In each repository, create a section in your AI context file or README that points to the platform repository:

```markdown
## Platform Documentation

This repository follows the standards and patterns defined in the 
[Platform Repository](https://github.com/dr3dr3/platform).

Key references:
- [Git Branching Strategy](https://github.com/dr3dr3/platform/blob/main/docs/git-branching.md)
- [Architecture Decision Records](https://github.com/dr3dr3/platform/tree/main/docs/adrs)
- [Coding Standards](https://github.com/dr3dr3/platform/blob/main/docs/coding-standards.md)
- [Security Policies](https://github.com/dr3dr3/platform/blob/main/docs/security.md)
```

### When to Use Reference Links

- ADRs and architectural context
- Detailed explanations of "why" decisions were made
- Policies and governance documentation
- Onboarding and background reading

### Reference Links: Advantages and Disadvantages

**Advantages**: Always current, no sync overhead, single maintenance point

**Disadvantages**: Requires network access for AI to fetch, adds latency, AI may not automatically fetch without prompting

## Pattern 2: Synced Documentation (Clone from Platform)

For frequently-referenced documentation, sync copies to each repository.

### Manual Sync

For simple setups or occasional updates:

```bash
# From the consuming repository
mkdir -p docs/shared
curl -o docs/shared/git-branching.md \
  https://raw.githubusercontent.com/dr3dr3/platform/main/docs/git-branching.md
curl -o docs/shared/commit-conventions.md \
  https://raw.githubusercontent.com/dr3dr3/platform/main/docs/commit-conventions.md
```

### Automated Sync with GitHub Actions

For reliable, consistent updates across repositories:

```yaml
# .github/workflows/sync-platform-docs.yml
name: Sync Platform Documentation

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday at 6am UTC
  workflow_dispatch:      # Manual trigger
  repository_dispatch:
    types: [platform-docs-updated]  # Triggered from platform repo

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Create shared docs directory
        run: mkdir -p docs/shared
        
      - name: Fetch shared documentation
        run: |
          # Define source repository
          SOURCE_REPO="dr3dr3/platform"
          SOURCE_BRANCH="main"
          BASE_URL="https://raw.githubusercontent.com/${SOURCE_REPO}/${SOURCE_BRANCH}"
          
          # Fetch each shared document
          curl -sf -o docs/shared/git-branching.md \
            "${BASE_URL}/docs/git-branching.md" || echo "Warning: git-branching.md not found"
          curl -sf -o docs/shared/commit-conventions.md \
            "${BASE_URL}/docs/commit-conventions.md" || echo "Warning: commit-conventions.md not found"
          curl -sf -o docs/shared/pr-checklist.md \
            "${BASE_URL}/docs/pr-checklist.md" || echo "Warning: pr-checklist.md not found"
          curl -sf -o docs/shared/code-review.md \
            "${BASE_URL}/docs/code-review.md" || echo "Warning: code-review.md not found"
            
      - name: Add sync metadata
        run: |
          cat > docs/shared/.sync-metadata.json << EOF
          {
            "source_repo": "dr3dr3/platform",
            "source_branch": "main",
            "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "source_commit": "$(curl -sf https://api.github.com/repos/dr3dr3/platform/commits/main | jq -r '.sha[:7]')"
          }
          EOF
          
      - name: Check for changes
        id: changes
        run: |
          git add docs/shared/
          if git diff --staged --quiet; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
          fi
          
      - name: Commit and push changes
        if: steps.changes.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -m "chore: sync shared documentation from platform repo"
          git push
```

### Triggering Sync from Platform Repository

Add this workflow to your platform repository to notify other repos when docs change:

```yaml
# In platform repo: .github/workflows/notify-docs-update.yml
name: Notify Documentation Update

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'

jobs:
  notify:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repo:
          - dr3dr3/repo-a
          - dr3dr3/repo-b
          - dr3dr3/repo-c
    steps:
      - name: Trigger sync in ${{ matrix.repo }}
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.REPO_DISPATCH_TOKEN }}
          repository: ${{ matrix.repo }}
          event-type: platform-docs-updated
```

### When to Use Synced Documentation

- Git workflow quick references
- Commit message conventions
- PR templates and checklists
- Frequently-referenced standards

### Synced Documentation: Advantages and Disadvantages

**Advantages**: Always locally available, fast for AI access, works offline

**Disadvantages**: Can drift if sync fails, requires automation setup, duplicate storage

## Layered AI Context

The key to effective AI assistance across repositories is providing context in layers, from most specific (local) to most general (platform).

### Layer Structure

```text
Layer 1: Immediate Context (Current File/Task)
    ↓
Layer 2: Repository Context (Local Docs)
    ↓
Layer 3: Shared Context (Synced Docs)
    ↓
Layer 4: Platform Context (Fetched on Demand)
```

### Claude Projects / Claude Code Setup

Claude uses a `CLAUDE.md` file in the repository root for context. Structure it to provide layered information:

```markdown
# CLAUDE.md

## About This Repository

[Brief description of what this repository does, its purpose, and key technologies]

This is a [type of project, e.g., "Node.js API service"] that [primary function].

## Quick Reference

### Key Commands
- `npm run dev` - Start development server
- `npm test` - Run test suite
- `npm run lint` - Check code style

### Project Structure

```text
src/
├── api/         # API route handlers
├── services/    # Business logic
├── models/      # Data models
└── utils/       # Shared utilities
```

## Local Documentation

For repository-specific information, see:

- [API Documentation](./docs/api.md)
- [Data Models](./docs/models.md)
- [Local Development](./docs/development.md)

## Shared Documentation (Synced from Platform)

These documents are synced from the platform repository and apply to all projects:

- [Git Branching Strategy](./docs/shared/git-branching.md)
- [Commit Conventions](./docs/shared/commit-conventions.md)
- [PR Checklist](./docs/shared/pr-checklist.md)
- [Code Review Guidelines](./docs/shared/code-review.md)

## Platform Documentation (Fetch When Needed)

For broader context, architectural decisions, and detailed policies, refer to the
[Platform Repository](https://github.com/dr3dr3/platform):

- [Architecture Decision Records](https://github.com/dr3dr3/platform/tree/main/docs/adrs) -
  Technical decisions and their rationale
- [Security Policies](https://github.com/dr3dr3/platform/blob/main/docs/security.md) -
  Authentication, secrets, vulnerability handling
- [CI/CD Patterns](https://github.com/dr3dr3/platform/blob/main/docs/cicd.md) -
  Pipeline templates and deployment strategies
- [Full Standards Documentation](https://github.com/dr3dr3/platform/tree/main/docs) -
  Complete platform documentation index

## Conventions for This Repository

### Code Style

- [Specific linting rules or style choices for this repo]
- [Framework-specific patterns used here]

### Testing

- [Testing approach for this specific project]
- [Key test utilities or patterns]

### Dependencies

- [Notable dependencies and why they were chosen]

### GitHub Copilot Setup

Copilot uses `.github/copilot-instructions.md` for repository-level context. Structure similarly:

```markdown
# Copilot Instructions

## Repository Overview

This repository is [description]. It uses [key technologies] and follows 
the patterns established in our platform repository.

## Code Conventions

### Style
- Use [language-specific conventions]
- Follow [framework patterns]
- Naming: [conventions for this repo]

### Patterns
- [Common patterns used in this codebase]
- [Anti-patterns to avoid]

## Documentation References

When asked about cross-cutting concerns, refer to these resources:

### Local (in this repo)
- `docs/` - Repository-specific documentation
- `docs/shared/` - Synced platform documentation

### Platform (external)
- Git workflow: https://github.com/dr3dr3/platform/blob/main/docs/git-branching.md
- Coding standards: https://github.com/dr3dr3/platform/blob/main/docs/coding-standards.md
- ADRs: https://github.com/dr3dr3/platform/tree/main/docs/adrs

## Common Tasks

### Creating a new feature
1. Branch from `main` using pattern: `feature/[description]`
2. Follow commit conventions in `docs/shared/commit-conventions.md`
3. Create PR using checklist in `docs/shared/pr-checklist.md`

### Adding a new API endpoint
1. Add route handler in `src/api/`
2. Add service logic in `src/services/`
3. Add tests in `tests/`
4. Update `docs/api.md`
```

### Cursor Setup

Cursor uses `.cursorrules` for project-level instructions:

```markdown
# Cursor Rules

## Project Context

This is a [project type] repository. It follows platform standards from 
https://github.com/dr3dr3/platform.

## Key Files to Reference

When working in this repository, these files provide important context:
- `CLAUDE.md` - Full repository context and documentation links
- `docs/shared/` - Synced platform documentation
- `docs/` - Local project documentation

## Code Generation Guidelines

When generating code:
1. Follow patterns established in existing files
2. Use conventions from `docs/shared/commit-conventions.md` for commits
3. Reference `docs/shared/git-branching.md` for branch naming

## Documentation Links

For platform-wide standards:
- https://github.com/dr3dr3/platform/blob/main/docs/coding-standards.md
- https://github.com/dr3dr3/platform/tree/main/docs/adrs
```

### Windsurf Setup

Windsurf uses `.windsurfrules`:

```markdown
# Windsurf Rules

## Repository Information
- Type: [project type]
- Technologies: [key technologies]
- Platform docs: https://github.com/dr3dr3/platform

## Context Files
- `CLAUDE.md` - Primary documentation index
- `docs/shared/` - Synced shared documentation
- `docs/` - Local documentation

## Conventions
[Similar content to Cursor rules]
```

## Directory Structure Template

Here's the recommended structure for repositories:

```text
repository/
├── .github/
│   ├── copilot-instructions.md    # GitHub Copilot context
│   └── workflows/
│       └── sync-platform-docs.yml # Documentation sync automation
├── .cursorrules                    # Cursor context
├── .windsurfrules                  # Windsurf context
├── CLAUDE.md                       # Claude context (also useful for humans)
├── README.md                       # Standard project readme
├── docs/
│   ├── api.md                     # Local: API documentation
│   ├── development.md             # Local: Development setup
│   ├── models.md                  # Local: Data models
│   └── shared/                    # Synced from platform
│       ├── .sync-metadata.json    # Sync tracking
│       ├── git-branching.md
│       ├── commit-conventions.md
│       ├── pr-checklist.md
│       └── code-review.md
└── src/
    └── ...
```

## Platform Repository Structure

Your central platform repository should be organised to support this pattern:

```text
platform/
├── README.md                       # Platform overview and navigation
├── docs/
│   ├── index.md                   # Documentation index
│   ├── git-branching.md           # Shared: Git workflow
│   ├── commit-conventions.md      # Shared: Commit format
│   ├── pr-checklist.md            # Shared: PR checklist
│   ├── code-review.md             # Shared: Review guidelines
│   ├── coding-standards.md        # Reference: Code standards
│   ├── security.md                # Reference: Security policies
│   ├── cicd.md                    # Reference: CI/CD patterns
│   └── adrs/                      # Reference: Architecture decisions
│       ├── index.md
│       ├── 001-adr-template.md
│       └── ...
├── templates/                      # Repository templates
│   ├── CLAUDE.md.template
│   ├── copilot-instructions.md.template
│   └── sync-workflow.yml.template
└── scripts/
    └── setup-new-repo.sh          # Script to bootstrap new repos
```

### Documentation Manifest

Consider adding a manifest file that explicitly declares which docs should be synced:

```yaml
# docs/sync-manifest.yml
version: 1
sync_targets:
  - path: docs/git-branching.md
    description: Git branching strategy and workflow
    sync_to_repos: all
    
  - path: docs/commit-conventions.md
    description: Commit message format and conventions
    sync_to_repos: all
    
  - path: docs/pr-checklist.md
    description: Pull request checklist
    sync_to_repos: all
    
  - path: docs/code-review.md
    description: Code review guidelines
    sync_to_repos: all

reference_only:
  - path: docs/adrs/
    description: Architecture Decision Records
    
  - path: docs/security.md
    description: Security policies and practices
    
  - path: docs/cicd.md
    description: CI/CD patterns and templates
```

## Workflow Summary

### Setting Up a New Repository

1. Create repository from template (if available)
2. Copy sync workflow from platform templates
3. Create `CLAUDE.md` using template, customise for this repo
4. Create `.github/copilot-instructions.md` using template
5. Run initial documentation sync
6. Add repository to platform's notification list

### Making Platform Documentation Changes

1. Update documentation in platform repository
2. Platform CI triggers sync notification to all repos
3. Each repo's sync workflow fetches updated docs
4. Automated PR or direct commit updates synced docs

### Using AI Assistants

1. AI reads local context file (`CLAUDE.md`, `.github/copilot-instructions.md`)
2. For immediate questions, AI uses local and synced docs
3. For deeper context, AI fetches from platform repository URLs
4. Human can explicitly direct AI to specific platform docs when needed

## Maintenance

### Regular Tasks

- **Weekly**: Review sync workflow runs for failures
- **Monthly**: Audit synced docs against platform for drift
- **Quarterly**: Review which docs should be synced vs referenced

### Keeping Context Files Updated

When you make significant changes to a repository:

1. Update `CLAUDE.md` with new patterns, commands, or structure
2. Update `.github/copilot-instructions.md` if needed
3. Ensure local docs in `docs/` reflect current state

### Handling Sync Failures

If documentation sync fails:

1. Check GitHub Actions logs for the failure reason
2. Verify platform repository URLs are still valid
3. Check if documents were renamed or moved
4. Update sync workflow if paths changed
5. Manually sync if urgent, fix automation after

## Tips for Effective AI Context

1. **Be specific in local docs**: AI context files should describe what makes this repo unique, not repeat general knowledge

2. **Use clear section headers**: AI assistants parse headers to find relevant sections quickly

3. **Include examples**: Code examples in context files help AI match your patterns

4. **Keep it current**: Outdated context leads to outdated suggestions

5. **Layer appropriately**: Don't duplicate platform docs in local context; link to them instead

6. **Test your context**: Periodically ask AI questions about your project conventions to verify it's reading your context correctly

## Conclusion

This approach gives you:

- **Single source of truth**: Platform repository owns cross-cutting documentation
- **Local availability**: Frequently-used docs synced to each repo
- **AI-ready context**: Layered structure that AI assistants can navigate
- **Low maintenance**: Automated sync keeps docs aligned
- **Flexibility**: Reference links for detailed docs, local copies for quick reference

The key is deciding which docs need to be immediately available (sync them) versus which provide background context (link to them). Start with syncing only the most frequently referenced docs, and expand based on your actual usage patterns.
