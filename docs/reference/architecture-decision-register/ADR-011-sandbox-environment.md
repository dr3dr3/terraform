# ADR-011: Sandbox Environment for Testing and Experimentation

## Status

Approved

## Date

2025-11-17

## Context

As our infrastructure grows and team members need to learn new technologies, test new patterns, and validate changes before deploying to Development, we need a dedicated environment that:

1. **Enables Safe Experimentation**: Team members should be able to try new AWS services and Terraform patterns without risk
2. **Supports Automated Testing**: Integration tests should run in an isolated environment
3. **Facilitates Learning**: New team members need a safe place to learn IaC practices
4. **Validates Changes**: Infrastructure changes should be tested before Development deployment
5. **Controls Costs**: Experimentation shouldn't lead to runaway costs
6. **Maintains Cleanliness**: Old experiments shouldn't accumulate indefinitely

### Problems We're Solving

**Current Situation**:

- No dedicated testing environment
- Testing in Development risks breaking shared infrastructure
- New team members hesitant to experiment
- Integration tests compete with development work
- No safe place to try new AWS services
- Difficult to validate Terraform changes before applying

**Requirements**:

- Separate AWS account for complete isolation
- Broader permissions for experimentation
- Automated cleanup of old resources
- Cost controls and monitoring
- Support for both structured testing and ad-hoc experiments
- Clear guidelines on what goes where

## Decision

### Create Dedicated Sandbox AWS Account and Environment

We will create a separate AWS account called **Sandbox** with corresponding Terraform environment structure `env-sandbox/` that includes:

1. **Standard Infrastructure Layers**: Foundation, Platform, Applications (like other environments)
2. **Experiments Layer**: Unique to Sandbox for ad-hoc testing
3. **Broader Permissions**: More permissive IAM roles with safeguards
4. **Automated Cleanup**: Resources tagged for automatic cleanup
5. **Cost Controls**: Spending limits and alerts

### Environment Structure

```text
env-sandbox/
├── foundation-layer/
│   └── iam-roles-terraform/      # IAM roles for all layers
├── platform-layer/                # Test platform services (EKS, RDS, etc.)
├── applications-layer/            # Test application deployments
└── sandbox-layer/                 # Unique to Sandbox
    └── experiments/               # Ad-hoc experiments
```

### Access Control

#### IAM OIDC Roles (GitHub Actions)

**Foundation Layer**:

- `terraform-sandbox-foundation-cicd-role`: For CI/CD (2 hour sessions)
- `terraform-sandbox-foundation-human-role`: For humans (12 hour sessions)

**Platform Layer**:

- `terraform-sandbox-platform-cicd-role`: For CI/CD (2 hour sessions)
- `terraform-sandbox-platform-human-role`: For humans (12 hour sessions)

**Application Layer**:

- `terraform-sandbox-application-cicd-role`: For CI/CD (2 hour sessions)
- `terraform-sandbox-application-human-role`: For humans (12 hour sessions)

**Experiments Layer** (Sandbox-Specific):

- `terraform-sandbox-experiments-human-role`: Broad permissions for experimentation (12 hour sessions)

#### IAM Identity Center Permission Sets

- `SandboxFoundationAdmin`: Foundation layer access
- `SandboxPlatformAdmin`: Platform layer access
- `SandboxApplicationAdmin`: Application layer access
- `SandboxExperimentsAdmin`: PowerUser + additional services (with safeguards)

#### Permission Characteristics

**More Permissive Than Other Environments**:

- Longer session durations (12 hours for human roles vs 2-4 hours in other environments)
- Broader service permissions in Experiments layer
- PowerUser access available in Experiments permission set

**Safeguards**:

- Cannot modify account-level settings
- Cannot change organization settings
- All actions logged and auditable
- Resources must be tagged
- Cost limits enforced

### Tagging Strategy

All resources in Sandbox must include:

```hcl
tags = {
  Environment  = "Sandbox"
  ManagedBy    = "Terraform"
  Layer        = "foundation|platform|applications|experiments"
  Owner        = "team-or-person-name"
  Purpose      = "testing|learning|experiment|integration-test"
  ExpiresOn    = "2025-11-24"  # ISO date
  AutoCleanup  = "true"
  MaxLifetime  = "7days"       # Or appropriate value
}
```

### Cost Management

**Budget Alerts**:

- Warning: $500/month
- Critical: $1000/month
- Per-owner tracking via tags

**Cost Optimization**:

- Use smallest viable instance types
- Schedule shutdowns (e.g., overnight, weekends)
- Automated cleanup of old resources
- Spot instances where appropriate

**Automated Cleanup** (To Be Implemented):

- Daily: Remove resources past `MaxLifetime`
- Weekly: Cleanup untagged resources
- On-demand: Manual cleanup for specific experiments

### Terraform Cloud Workspaces

```text
sandbox-foundation-iam-roles       → env-sandbox/foundation-layer/iam-roles-terraform/
sandbox-platform-*                 → env-sandbox/platform-layer/*/
sandbox-app-*                      → env-sandbox/applications-layer/*/
sandbox-experiments-*              → env-sandbox/sandbox-layer/experiments/*/
```

### Use Cases and Layer Assignment

| Use Case | Layer | Example |
|----------|-------|---------|
| Test VPC changes | Foundation | New subnet configuration |
| Test EKS upgrade | Platform | EKS 1.28 → 1.29 |
| Test app deployment | Applications | New Helm chart pattern |
| Integration tests | Applications | Automated test suite |
| Try new AWS service | Experiments | Test AWS App Runner |
| Learning project | Experiments | Individual learning EKS |
| Proof of concept | Experiments | Service mesh evaluation |
| Tool trial | Experiments | Test CDK for Terraform |

### Testing Workflow

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Local Testing (LocalStack, terraform validate)          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Sandbox Testing (Real AWS, isolated from other envs)    │
│    - Integration tests                                      │
│    - Experiments                                            │
│    - Learning                                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Development (Shared dev environment)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Staging (Production-like)                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Production                                                │
└─────────────────────────────────────────────────────────────┘
```

## Rationale

### Why Separate AWS Account?

**Complete Isolation**:

- No risk to Development/Staging/Production
- Separate billing for cost tracking
- Independent resource limits
- Can apply aggressive cleanup policies
- Different compliance requirements

**Clear Boundary**:

- Explicit separation between testing and development
- Prevents accidental changes to shared resources
- Distinct permissions model
- Independent disaster recovery policies

### Why Standard Layers + Experiments Layer?

**Standard Layers (Foundation, Platform, Applications)**:

- Test infrastructure changes systematically
- Validate module changes before Development
- Run integration tests in realistic environment
- Practice deployment procedures

**Experiments Layer** (Unique):

- Ad-hoc testing that doesn't fit standard patterns
- Personal learning projects
- Rapid prototyping
- Proof-of-concepts
- Tool evaluations

This hybrid approach supports both:

- **Structured testing**: Using standard patterns
- **Unstructured exploration**: Without forcing structure

### Why Broader Permissions?

**Learning Effectiveness**:

- Team members can learn without constant permission requests
- Faster feedback loops for experiments
- Encourages innovation and learning
- Reduces friction in testing new services

**With Safeguards**:

- Cannot break the account itself
- Cannot modify organization
- All actions logged
- Cost limits prevent runaway spending
- Resources automatically cleaned up

### Why Automated Cleanup?

**Prevent Accumulation**:

- Old experiments shouldn't linger
- Reduces costs over time
- Maintains clean environment
- Forces good hygiene

**Tag-Based Approach**:

- `AutoCleanup = "true"`: Eligible for cleanup
- `MaxLifetime = "7days"`: Age threshold
- `ExpiresOn = "2025-11-24"`: Explicit date
- `Protected = "true"`: Prevent cleanup if needed

## Consequences

### Positive

✅ **Safe Experimentation**: Team can test freely without risk

✅ **Learning Environment**: New members have safe space to learn

✅ **Better Testing**: Integration tests don't interfere with development

✅ **Validation**: Changes tested before Development deployment

✅ **Innovation**: Lower barrier to trying new services/patterns

✅ **Cost Control**: Separate billing, automated cleanup, budget alerts

✅ **Clear Guidelines**: Well-documented what goes where

✅ **Flexible Structure**: Supports both structured and ad-hoc testing

### Negative

❌ **Additional Account**: Another AWS account to manage

❌ **Initial Setup**: Time to configure account and permissions

❌ **Cost**: Additional AWS account (though minimal for testing)

❌ **Complexity**: Another environment in documentation

❌ **Maintenance**: Need to maintain cleanup automation

### Neutral

⚪ **Different Permissions**: More permissive than other environments (by design)

⚪ **Experiments Layer**: Unique structure only in Sandbox

⚪ **Learning Curve**: Team needs to understand Sandbox purpose and rules

## Implementation Plan

### Phase 1: Account Setup ✅ COMPLETE

- [x] Create `env-sandbox/` directory structure
- [x] Create Foundation layer IAM roles configuration
- [x] Create comprehensive documentation

### Phase 2: Account Creation (Next)

- [ ] Create Sandbox AWS account in organization
- [ ] Configure OIDC provider for GitHub Actions
- [ ] Set up IAM Identity Center access
- [ ] Configure billing alerts and budgets

### Phase 3: Terraform Cloud (Next)

- [ ] Create `sandbox-foundation-iam-roles` workspace
- [ ] Configure VCS connection to repository
- [ ] Set working directory: `terraform/env-sandbox/foundation-layer/iam-roles-terraform/`
- [ ] Deploy IAM roles and permission sets

### Phase 4: Platform Services (Future)

- [ ] Create test EKS cluster (small)
- [ ] Create test RDS instance (micro)
- [ ] Set up basic monitoring

### Phase 5: Automated Cleanup (Future)

- [ ] Implement AWS Nuke or cloud-nuke configuration
- [ ] Create Lambda for tag-based cleanup
- [ ] Set up scheduled cleanup jobs
- [ ] Test cleanup automation

### Phase 6: Integration Testing (Future)

- [ ] Create CI/CD workflow for Sandbox testing
- [ ] Set up integration test suite
- [ ] Configure automated test runs
- [ ] Document testing procedures

## Success Metrics

Track these metrics after 3 months:

- **Usage**: Number of experiments per month
- **Learning**: Team members who used Sandbox for learning
- **Cost**: Average monthly Sandbox costs
- **Cleanup Rate**: Percentage of resources cleaned up automatically
- **Testing**: Number of integration tests run in Sandbox
- **Issues Caught**: Problems found in Sandbox before Development

## Review and Maintenance

### Monthly

- Review Sandbox costs
- Check for orphaned resources
- Audit recent experiments
- Update documentation based on learnings

### Quarterly

- Review permissions (still appropriate?)
- Evaluate cleanup effectiveness
- Assess usage patterns
- Gather team feedback

### Annually

- Major review of Sandbox strategy
- Cost-benefit analysis
- Consider additional automation
- Update best practices

## Related Decisions

- [ADR-001: Terraform State Management](./ADR-001-terraform-state-management.md)
- [ADR-002: Terraform Workflow - Git, CI/CD, and Terraform Cloud](./ADR-002-terraform-workflow-git-cicd.md)
- [ADR-003: Infrastructure Layering and Repository Structure](./ADR-003-infra-layering-repository-structure.md)
- [ADR-009: Folder Structure](./ADR-009-folder-structure.md)
- [ADR-010: AWS IAM Role Structure](./ADR-010-aws-aim-role-structure.md)

## References

- [Terraform Testing Guide](../../../explanations/guide-to-testing-terraform.md)
- [Sandbox Environment README](../../../../terraform/env-sandbox/README.md)
- [Best Practices from "Terraform: Up & Running"](../../../to-do/best-practices-from-tf-up-book.md)
- [AWS Nuke](https://github.com/rebuy-de/aws-nuke)
- [Cloud Nuke](https://github.com/gruntwork-io/cloud-nuke)

---

**Decision Maker**: Platform Engineering Team  
**Approved By**: [To be assigned]  
**Review Date**: 2026-02-17 (3 months)
