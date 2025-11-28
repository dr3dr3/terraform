# ADR: AWS IAM Role Structure for Terraform OIDC Authentication

**Status:** Approved

**Date:** 2025-11-02

---

## Context

We have implemented OIDC SSO authentication for AWS to enable Terraform to manage infrastructure both from developer terminals and CICD pipelines. We need to establish a clear IAM role structure that balances security, operational efficiency, and team productivity while supporting integration with AWS Organizations and Terraform Cloud.

### Current Situation

- OIDC federation is configured between our identity provider and AWS
- Terraform operations occur in multiple contexts: developer terminals and CICD pipelines
- Infrastructure spans multiple environments (Dev, Staging, Production)
- Organization uses AWS Organizations for multi-account management
- IAM Identity Center (AWS SSO) is available for human user access

### Key Requirements

- Limit blast radius of configuration errors or security incidents
- Enable different approval workflows per environment
- Support audit and compliance requirements
- Allow flexible permissions appropriate to each environment
- Accommodate future organizational growth
- Maintain clear separation between human and automated access

---

## Decision

We will implement a **tiered IAM role structure** based on environment separation with optional layer-based subdivision for complex infrastructure.

### Core Role Structure

#### 1. Environment-Based Roles (Mandatory)

Create separate IAM roles for each environment:

- `terraform-dev-role`
- `terraform-staging-role`
- `terraform-production-role`

#### 2. Execution Context Split (Recommended)

Differentiate between human and automated execution:

- `terraform-{env}-cicd-role` - For CICD pipeline execution only
- `terraform-{env}-human-role` - For developer terminal usage

#### 3. Layer-Based Roles (Optional - For Mature Organizations)

For organizations with multiple teams or complex segregation requirements:

```text
Foundation Layer:
- terraform-{env}-foundation-{context}-role

Platform Layer:
- terraform-{env}-platform-{context}-role

Application Layer:
- terraform-{env}-application-{context}-role
```

Where `{context}` is either `cicd` or `human`.

### Implementation Phases

**Phase 1 (Immediate):** Environment separation only

- 3 roles: dev, staging, production
- Suitable for teams < 10 people

**Phase 2 (As needed):** Add execution context split

- 6 roles: (dev, staging, prod) × (cicd, human)
- Implement when CICD workflow matures or compliance requires segregation

**Phase 3 (Future):** Add layer-based subdivision

- 18+ roles: (dev, staging, prod) × (foundation, platform, application) × (cicd, human)
- Implement when multiple teams manage different infrastructure domains

### AWS Organizations & IAM Identity Center Integration

**Separation of Concerns:**

- **OIDC IAM Roles:** Used exclusively for Terraform authentication and execution
- **IAM Identity Center Permission Sets:** Used for human AWS Console/CLI access for non-Terraform operations

**Alignment Strategy:**

- Maintain similar permission boundaries between OIDC roles and Permission Sets
- Use Permission Sets for day-to-day AWS access
- Use OIDC roles specifically for Terraform workflows
- Deploy roles consistently across accounts using AWS Organizations

### Role Configuration Standards

#### Trust Policy Requirements

**For CICD Roles:**

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/OIDC_PROVIDER"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "OIDC_PROVIDER:sub": "repo:ORG/REPO:ref:refs/heads/main",
        "OIDC_PROVIDER:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**For Human Roles:**

- Use subject claims from IdP (email, group membership)
- Allow multiple users/groups based on organizational structure
- Consider integration with identity provider group claims

#### Permission Design Principles

1. **Least Privilege:** Grant only permissions necessary for Terraform operations
2. **Environment-Appropriate:**
   - Production: Minimal permissions, read-heavy, specific resource modification
   - Staging: Moderate permissions, mirrors production constraints
   - Dev: Broader permissions for experimentation
3. **Permission Boundaries:** Enforce maximum permission ceiling across all roles
4. **Session Duration:**
   - Production: 1-2 hours (forces re-authentication)
   - Staging: 2-4 hours
   - Dev: 4-12 hours (reduces friction)

#### Compliance & Audit

- Tag all roles with: `Environment`, `Purpose`, `ManagedBy`, `Owner`
- Enable CloudTrail logging for all AssumeRole events
- Implement alerts for production role usage outside expected patterns
- Regular access reviews (quarterly minimum for production)

---

## Consequences

### Positive

- **Security:** Limited blast radius through environment isolation
- **Compliance:** Clear audit trails and role segregation
- **Flexibility:** Can grow structure as organization scales
- **Clarity:** Explicit separation of human vs automated access
- **Control:** Different approval workflows per environment possible
- **Scalability:** Structure supports multi-team organizations

### Negative

- **Complexity:** More roles to manage and maintain
- **Initial Setup:** Higher upfront configuration effort
- **Documentation:** Requires clear documentation for developers
- **Cognitive Load:** Developers need to understand which role to use when

### Mitigations

- Start with Phase 1 (environment separation only) and add complexity as needed
- Create clear documentation and developer guides
- Implement helper scripts/tooling to simplify role selection
- Use consistent naming conventions across all roles
- Automate role creation and updates using Terraform

### Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Over-permissive role in production | High | Medium | Implement permission boundaries, regular audits |
| Developer confusion about which role to use | Medium | High | Clear documentation, helper tooling |
| Role proliferation makes management difficult | Medium | Medium | Start minimal, grow as needed; use IaC for role management |
| OIDC trust policy misconfiguration | High | Low | Thorough testing in dev first; peer review for prod changes |

---

## Alternatives Considered

### Alternative 1: Single Role for All Environments

**Description:** Use one IAM role for all Terraform operations across all environments.

**Rejected Because:**

- Unacceptable security risk (dev error affects production)
- No way to enforce different approval workflows
- Fails most compliance frameworks
- Unlimited blast radius

### Alternative 2: Per-User IAM Roles

**Description:** Create individual IAM roles for each developer.

**Rejected Because:**

- Difficult to manage at scale
- Complicates offboarding
- Harder to standardize permissions
- OIDC federation already provides user identity
- Doesn't solve CICD authentication

### Alternative 3: Rely Solely on IAM Identity Center Permission Sets

**Description:** Use Permission Sets for both human access and Terraform operations.

**Rejected Because:**

- Permission Sets not designed for programmatic CICD access
- Harder to implement fine-grained OIDC trust policies
- Mixing human console access with Terraform execution contexts
- Less flexibility for Terraform-specific permission patterns

---

## Implementation Plan

### Phase 1: Foundation (Weeks 1-2)

1. Create environment-specific OIDC IAM roles in each AWS account
2. Configure trust policies with appropriate OIDC provider conditions
3. Define and attach permission policies (start conservative)
4. Update Terraform backend configuration
5. Update CICD pipeline configuration
6. Test thoroughly in dev environment

### Phase 2: Documentation & Enablement (Week 3)

1. Document role usage guidelines for developers
2. Create helper scripts for local Terraform execution
3. Update onboarding documentation
4. Conduct team training session

### Phase 3: Monitoring & Refinement (Week 4+)

1. Enable CloudTrail monitoring and alerting
2. Review initial usage patterns
3. Adjust permissions based on actual needs
4. Implement regular audit process

### Future Phases (As Needed)

- Phase 4: Add execution context split (human vs CICD)
- Phase 5: Implement layer-based subdivision if multi-team structure emerges

---

## References

- [AWS IAM Roles for OIDC Federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [Terraform Cloud OIDC Configuration](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [IAM Identity Center Permission Sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html)

---

## Notes

- This ADR should be reviewed after 6 months of implementation
- Team size and organizational changes may trigger need for Phase 2/3 implementation
- Consider future ADRs for specific permission policy definitions per role
- Monitor for AWS feature updates that may impact this architecture

---

**Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-02 | Andre Dreyer | Initial version |
