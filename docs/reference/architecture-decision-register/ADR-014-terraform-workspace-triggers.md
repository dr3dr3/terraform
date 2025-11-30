# ADR-014: Terraform Workspace Trigger Strategy

| Field | Value |
|-------|-------|
| **Status** | Approved |
| **Date** | November 2025 |
| **Decision Makers** | Platform Engineering Team |
| **Scope** | All Terraform workspaces across 4 AWS accounts |

## Context

We manage infrastructure across four AWS accounts (management, development, staging, production) using Terraform Cloud/Enterprise workspaces. Our infrastructure follows a layered approach, with each layer having different change frequencies and risk profiles.

Terraform Cloud offers three workflow trigger mechanisms, each with distinct characteristics:

1. **VCS-driven:** Automatic triggers on commits/merges to connected repository branches with speculative plans on pull requests
2. **CLI-driven:** Manual execution via Terraform CLI with remote state management
3. **API-driven (GitHub Actions):** Programmatic triggers via CI/CD pipelines with custom workflow logic

### Infrastructure Layers

| Layer | Components | Change Frequency |
|-------|------------|------------------|
| **Foundation/Shared** | VPCs, IAM, security groups, DNS, certificates | Weeks to months |
| **Application** | EKS/ECS, app databases, load balancers, auto-scaling | Days to weeks |
| **Platform** | EKS clusters, monitoring, backup, security scanning | Variable (frequent create/destroy cycles for cost optimisation) |

### Additional Considerations

**Cost Optimisation Pattern:** Development and sandbox EKS clusters can be expensive if left running. Since this is a learning environment, clusters are provisioned manually when needed and should be destroyed after learning sessions. To prevent forgotten clusters from accumulating costs, we use a TTL (Time-To-Live) based auto-destroy mechanism rather than scheduled create/destroy cycles.

**Learning All Three Trigger Mechanisms:** This infrastructure serves as a learning environment for production-grade workflows. To gain hands-on experience with all three Terraform Cloud trigger mechanisms (CLI, VCS, API/GitHub Actions), we deliberately use each approach where it provides learning value while remaining appropriate for the risk level.

## Decision

We will adopt a tiered trigger strategy using all three Terraform Cloud trigger mechanisms, allowing practice with each approach while matching risk levels appropriately:

| Workspace Layer | Trigger | Apply Mode | Destroy Mode | Rationale |
|-----------------|---------|------------|--------------|-----------|
| Foundation (all envs) | CLI | Manual | Manual | Maximum control for high-impact changes |
| Application (dev) | API/GHA | Auto-apply | Manual + TTL | Fast iteration with TTL safety net |
| Application (staging) | **VCS** | Manual | Manual | Learn VCS triggers; speculative plans on PRs |
| Application (prod) | API/GHA | Manual | Manual | CI/CD gates, audit trail, approvals |
| Platform (dev) | API/GHA | Auto-apply | Manual + TTL | TTL-based auto-destroy for cost protection |
| Platform (sandbox) | **VCS** | Auto-apply | Manual | Learn VCS with auto-apply; low-risk experimentation |
| Platform (staging/prod) | API/GHA | Manual | Manual | Production-like controls with CI/CD benefits |

### TTL-Based Cost Protection

Rather than scheduled create/destroy cycles, we use a TTL (Time-To-Live) mechanism for ephemeral learning resources:

1. **On provisioning:** Clusters are tagged with `TTL_Hours`, `CreatedAt`, and `DestroyBy` timestamps
2. **Default TTL:** 8 hours (configurable per apply, 0 = no auto-destroy)
3. **Hourly check:** A scheduled workflow checks all clusters for TTL expiration
4. **Auto-destroy:** Expired clusters are automatically destroyed

This approach is better suited for learning environments because:

- **No wasted resources:** Clusters only exist when actively needed
- **Flexible timing:** Create when you want, not on a schedule
- **Safety net:** Forgotten clusters are cleaned up automatically
- **Cost predictable:** Maximum cost is limited by TTL duration

### Trigger Mechanism Summary

| Trigger Type | Workspaces | Learning Focus |
|--------------|------------|----------------|
| **CLI-driven** | Foundation (all envs) | Manual control, change windows, highest-risk changes |
| **VCS-driven** | Application (staging), Platform (sandbox) | Automatic speculative plans, GitOps flow, PR-based workflows |
| **API/GHA-driven** | Application (dev/prod), Platform (dev/staging/prod) | CI/CD integration, TTL-based lifecycle, approval gates |

## Detailed Rationale

### Foundation/Shared Infrastructure → CLI-driven

Foundation infrastructure has the largest blast radius. Changes to VPCs, IAM policies, or shared databases can cascade across all applications and environments.

1. **Maximum control:** Operators explicitly initiate changes with full awareness of timing and impact
2. **No accidental triggers:** Prevents unintended infrastructure changes from errant commits or merge timing
3. **Change window alignment:** Allows coordination with maintenance windows and stakeholder communication
4. **Four-eyes principle:** PR review for code changes, separate manual apply for execution
5. **Rare destroys:** Foundation resources are long-lived; manual destroy is appropriate

### VCS-driven Workspaces → Application (Staging) & Platform (Sandbox)

VCS-driven workflows provide native Terraform Cloud integration with Git, offering automatic speculative plans and a pure GitOps experience.

#### Why Application Staging for VCS?

1. **Speculative plans on PRs:** Automatic plan generation when PRs touch staging infrastructure code
2. **GitOps purity:** Changes flow directly from Git to Terraform Cloud without intermediary CI/CD
3. **Learning value:** Understand how VCS triggers work, file path filters, and workspace queuing
4. **Manual apply gate:** Low-risk learning—automatic plans but controlled applies
5. **No scheduled destroys needed:** Staging resources are long-lived

#### Why Platform Sandbox for VCS?

1. **Experimentation friendly:** Sandbox is designed for trying things; VCS auto-apply accelerates iteration
2. **Immediate feedback:** Merge to main → automatic apply; see results quickly
3. **Low risk:** Sandbox failures have zero impact on real workloads
4. **Contrast with dev:** Compare VCS auto-apply (sandbox) vs API/GHA auto-apply (dev) experiences
5. **Manual destroys acceptable:** Sandbox resources destroyed on-demand, not on schedule

### API/GitHub Actions Infrastructure → Application & Platform (Dev/Prod)

GitHub Actions provides the flexibility needed for modern infrastructure lifecycle management.

#### Development: API/GHA with Auto-apply + TTL

1. Enables rapid iteration without workflow friction
2. Plans generated on PRs provide immediate feedback during development
3. **TTL-based destroy:** Clusters tagged with TTL; hourly check auto-destroys expired clusters
4. Low risk: development environment failures don't impact customers
5. **Practice value:** Mirrors production CI/CD patterns
6. **Manual provisioning:** Create clusters on-demand, not on a schedule

#### Staging (API alternative): API/GHA with Manual Apply

- If VCS limitations encountered, staging can switch to API/GHA
- Provides same speculative plan benefits via GitHub Actions
- Enables more complex workflows (multi-workspace orchestration)

#### Production: API/GHA with Manual Apply

- GitHub Actions provides comprehensive audit trail integrated with PR workflows
- Enables custom approval workflows, deployment windows, and rollback procedures
- Integration with existing CI/CD gates (tests, security scans, compliance checks)
- Manual apply ensures explicit human approval for production changes
- **No automated destroys:** Production destroys require explicit human approval

### Platform Layer (EKS Clusters) → Special Considerations

Platform infrastructure, particularly EKS clusters, has unique lifecycle requirements:

1. **Cost optimisation:** EKS clusters are expensive; dev/sandbox clusters should be ephemeral
2. **Scheduled lifecycle:** Create in morning, destroy in evening via GitHub Actions cron
3. **Weekend/holiday handling:** Automatic destruction prevents unnecessary costs
4. **Consistent state:** GitHub Actions ensures cluster configuration is reproducible
5. **Destroy safety:** GitHub Actions can include pre-destroy checks (no running workloads, backup verification)

## Alternatives Considered

### Option A: VCS-driven for Everything

**Rejected.** While simpler, this approach doesn't provide sufficient control for foundation infrastructure. Additionally, VCS-driven workflows cannot easily support scheduled destroys, which are essential for cost optimisation of ephemeral resources like development EKS clusters.

### Option B: CLI-driven for Everything

**Rejected.** Loses the benefits of automated workflows: no automatic speculative plans on PRs, no clear audit trail in version control, manual processes don't scale well with 50+ microservices, and no ability to schedule automated destroys.

### Option C: API/GitHub Actions for Everything (except Foundation)

**Rejected.** While this provides maximum flexibility, it misses the learning opportunity to practice VCS-driven workflows. VCS-driven is simpler for workspaces that don't need scheduled operations, and understanding its behaviour is valuable for advising teams on trigger selection.

### Option D: VCS-driven for Platform Layer (Dev)

**Rejected for Dev, Accepted for Sandbox.** Development EKS clusters need scheduled destroys for cost optimisation, which VCS cannot provide. However, sandbox is a good VCS candidate since it's manually destroyed and benefits from the simplicity of VCS triggers.

### Option E: API/GitHub Actions for Foundation Layer

**Rejected.** Foundation infrastructure changes rarely and has the highest blast radius. The additional complexity of GitHub Actions workflows isn't justified when CLI-driven provides maximum control and foundation resources don't benefit from scheduled lifecycle management.

## Consequences

### Positive

1. **Right-sized controls:** High-risk workspaces get maximum oversight; lower-risk workspaces get streamlined workflows
2. **Developer experience:** Fast feedback in dev, production-ready practices in staging/prod
3. **Audit compliance:** All non-foundation changes have full traceability through GitHub Actions or VCS
4. **Blast radius containment:** Foundation changes are explicitly controlled, limiting cascading failures
5. **Cost optimisation:** Scheduled destroys for development clusters reduce AWS spend significantly
6. **Complete learning coverage:** Hands-on experience with all three trigger mechanisms (CLI, VCS, API/GHA)
7. **Automated lifecycle:** Ephemeral resources can be created/destroyed on schedules without manual intervention
8. **Comparison opportunity:** Can directly compare VCS (sandbox) vs API/GHA (dev) for similar workloads

### Negative

- **Increased complexity:** GitHub Actions workflows required for most workspaces
- **GitHub Actions maintenance:** Workflows need ongoing maintenance and troubleshooting
- **Dependency on GitHub:** GitHub availability becomes critical for infrastructure changes
- **Learning curve:** Team needs to understand GitHub Actions + Terraform Cloud integration

### Mitigation

- Create clear documentation mapping workspaces to trigger types
- Standardise GitHub Actions workflows as reusable templates
- Include trigger type in workspace naming convention or tags
- Implement GitHub Actions workflow tests and validation
- Create fallback CLI procedures for GitHub outages

## Implementation Notes

### Workspace Configuration

| Workspace Pattern | Trigger | Execution Mode | Apply Method | VCS Connection | Destroy Method |
|-------------------|---------|----------------|--------------|----------------|----------------|
| `*-foundation-*` | CLI | Remote | Manual | None | Manual CLI |
| `*-app-dev-*` | API/GHA | Remote | Auto | None | Manual + TTL |
| `*-app-staging-*` | **VCS** | Remote | Manual | main branch | Manual (TFC UI) |
| `*-app-prod-*` | API/GHA | Remote | Manual | None | Manual GHA |
| `*-platform-dev-*` | API/GHA | Remote | Auto | None | Manual + TTL |
| `*-platform-sandbox-*` | **VCS** | Remote | Auto | main branch | Manual (TFC UI) |
| `*-platform-staging-*` | API/GHA | Remote | Manual | None | Manual GHA |
| `*-platform-prod-*` | API/GHA | Remote | Manual | None | Manual GHA |

### VCS-driven Workspace Settings

For VCS-connected workspaces (`*-app-staging-*`, `*-platform-sandbox-*`):

```hcl
vcs_repo {
  identifier     = "<org>/<repo>"
  branch         = "main"
  oauth_token_id = var.oauth_token_id
}

# Trigger only on changes to relevant paths
trigger_patterns = [
  "terraform/env-staging/applications-layer/**",  # For app-staging
  "terraform/env-sandbox/platform-layer/**"       # For platform-sandbox  
]
```

**VCS Workspace Behaviour:**

- **On PR creation/update:** Speculative plan runs automatically, visible in PR checks
- **On merge to main:** Plan queued; applies automatically (sandbox) or waits for approval (staging)
- **Destroy operations:** Initiated via Terraform Cloud UI with queue and confirmation

### GitHub Actions Integration

For API-driven workspaces, implement GitHub Actions workflows that:

**Provisioning Workflows:**

- Trigger plans on PR creation/update targeting infrastructure code paths
- Post plan output as PR comments for visibility
- Apply on merge to main branch (auto for dev, manual approval for staging/prod)
- Integrate with existing CI/CD gates (tests, security scans, compliance checks)
- **Tag resources with TTL metadata** (CreatedAt, DestroyBy, TTL_Hours)

**TTL Check Workflow:**

- Runs hourly via cron schedule
- Checks all EKS clusters for TTL expiration
- Auto-destroys clusters where current time > DestroyBy
- Supports dry-run mode for testing
- Provides summary of cluster status

**Manual Destroy Workflows:**

- Workflow dispatch triggers requiring explicit input confirmation
- Required reviewers for staging/production destroys
- Backup verification before destruction (where applicable)
- Audit log entry for compliance

### Example GitHub Actions Workflow Structure

```text
.github/workflows/
├── terraform-dev-platform-eks.yml    # EKS provisioning with TTL tagging
├── eks-ttl-check.yml                 # Hourly TTL check and auto-destroy
└── README.md                         # Workflow documentation
```

### TTL Configuration (Development/Learning EKS)

| TTL Setting | Behaviour | Use Case |
|-------------|-----------|----------|
| `8` (default) | Auto-destroy after 8 hours | Normal learning session |
| `4` | Auto-destroy after 4 hours | Quick experiments |
| `24` | Auto-destroy after 24 hours | Extended learning |
| `0` | No auto-destroy | Long-running tests (remember to destroy!) |

### TTL Tags Applied to Clusters

| Tag | Description | Example Value |
|-----|-------------|---------------|
| `TTL_Hours` | Configured TTL in hours | `8` |
| `CreatedAt` | ISO 8601 creation timestamp | `2025-11-30T10:00:00Z` |
| `DestroyBy` | ISO 8601 expiration timestamp | `2025-11-30T18:00:00Z` |
| `CreatedBy` | How the cluster was created | `github-actions` |
| `RunId` | GitHub Actions run ID for tracing | `12345678` |

## References

- HashiCorp: Which Terraform Workflow Should I Use?
- Terraform Cloud: VCS-driven Workflow Documentation
- Terraform Cloud: CLI-driven Workflow Documentation
- Terraform Cloud: API-driven Workflow Documentation
- Spacelift: Terraform Best Practices - Blast Radius Management
- AWS: Cost Optimisation with Scheduled Start/Stop
- GitHub Actions: Scheduled Workflows Documentation
