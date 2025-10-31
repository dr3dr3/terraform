# ADR-005: Selection of Cloud-Based Secrets Manager Service

## Status
Proposed

## Context
We are establishing a personal learning lab environment to gain hands-on experience with cloud infrastructure and DevOps practices that mirror production enterprise environments. As part of this setup, we need to select a secrets management service for storing and managing sensitive information such as API keys, database credentials, certificates, and other secrets.

### Requirements
- **Personal Learning Environment**: Single-user environment for educational purposes
- **Cost Optimization**: Minimize operational costs while maintaining production-like practices
- **Infrastructure as Code**: Must integrate seamlessly with Terraform
- **CI/CD Integration**: Must work with GitHub Actions pipelines
- **Cloud Provider**: Primary infrastructure is AWS-based
- **Managed Service**: No self-hosted solutions (e.g., HashiCorp Vault self-managed)
- **Best Practices**: Follow enterprise-grade security patterns despite being a learning environment

### Constraints
- Limited budget (personal expense)
- Single user/operator
- Learning-focused rather than production workloads
- Must support multi-environment patterns (dev, staging, prod simulation)

## Decision Drivers
1. **Cost**: Monthly operational costs and pricing model
2. **Terraform Integration**: Native provider support and maturity
3. **AWS Integration**: Seamless integration with AWS services
4. **GitHub Actions Support**: Ease of authentication and secret retrieval in CI/CD
5. **Learning Value**: Alignment with industry practices and career development
6. **Feature Set**: Rotation, versioning, audit logging, cross-service integration
7. **Operational Overhead**: Ease of setup and maintenance

## Options Considered

### Option 1: AWS Secrets Manager
**Description**: Fully managed secrets management service by AWS with native integration across AWS services.

**Pros**:
- Native AWS integration with RDS, ECS, Lambda, etc.
- Automatic secret rotation for supported AWS services
- Built-in encryption using AWS KMS
- Fine-grained IAM access control
- Excellent Terraform support via AWS provider
- Comprehensive audit logging via CloudTrail
- GitHub Actions has mature AWS authentication (OIDC)
- Industry-standard solution widely used in enterprises
- Secret versioning included

**Cons**:
- **Cost**: $0.40 per secret per month + $0.05 per 10,000 API calls
- Higher cost compared to alternatives for small-scale usage
- Overkill for single-user environments from a cost perspective

**Estimated Monthly Cost**: 
- 10 secrets: ~$4.00/month
- 20 secrets: ~$8.00/month
- Plus minimal API call costs (typically < $1/month for learning lab)

### Option 2: AWS Systems Manager Parameter Store
**Description**: Component of AWS Systems Manager for storing configuration data and secrets.

**Pros**:
- **Free tier**: Standard parameters are free (up to 10,000)
- Advanced parameters: $0.05 per parameter per month (very cost-effective)
- Native AWS integration (similar to Secrets Manager)
- Excellent Terraform support via AWS provider
- IAM-based access control
- CloudTrail audit logging
- Supports SecureString type with KMS encryption
- GitHub Actions compatible with AWS OIDC authentication
- Parameter versioning and history
- Widely used in production environments

**Cons**:
- No automatic secret rotation (manual implementation required)
- Less feature-rich than Secrets Manager
- 8 KB size limit per parameter (standard), 4 KB for advanced
- Not specifically designed for secrets (general-purpose configuration store)

**Estimated Monthly Cost**: 
- Standard parameters (10,000 limit): **$0.00/month**
- Advanced parameters: ~$1.00/month for 20 secrets

### Option 3: Azure Key Vault
**Description**: Microsoft Azure's secrets management service.

**Pros**:
- Robust secrets, keys, and certificate management
- **Cost-effective**: $0.03 per 10,000 operations (no per-secret charge)
- Excellent Terraform support via Azure provider
- Cross-cloud capability (can be used from AWS resources)
- Certificate management features
- RBAC and access policies

**Cons**:
- Requires Azure account and subscription setup
- Cross-cloud networking complexity (VPN/internet routing)
- Additional latency accessing from AWS resources
- GitHub Actions requires separate Azure authentication
- Less relevant for AWS-focused learning path
- Additional operational complexity managing multi-cloud

**Estimated Monthly Cost**: 
- Very low operation costs (~$0.50-1.00/month)
- But adds complexity cost

### Option 4: Google Cloud Secret Manager
**Description**: Google Cloud's managed secrets service.

**Pros**:
- Pay-per-use pricing (no per-secret monthly charge)
- Good Terraform support via GCP provider
- Secret versioning and rotation policies
- Fine-grained IAM
- Can be accessed cross-cloud

**Cons**:
- Requires GCP account setup
- Cross-cloud integration complexity from AWS
- GitHub Actions needs separate GCP authentication setup
- Less relevant to AWS-focused career path
- Network latency from AWS to GCP

**Estimated Monthly Cost**: 
- $0.06 per 10,000 access operations
- Storage: $0.10 per secret version per month (first 6 versions free)
- Very low cost (~$0.50-2.00/month) but complexity overhead

### Option 5: GitHub Secrets (Environment/Repository Secrets)
**Description**: GitHub's native secret storage for Actions workflows.

**Pros**:
- **Free** for GitHub users
- Zero additional infrastructure
- Native GitHub Actions integration
- Simple to use and manage
- No cross-cloud concerns
- Sufficient for CI/CD pipeline secrets

**Cons**:
- **Not suitable for application runtime secrets**
- Only accessible in GitHub Actions context
- No programmatic access from applications
- Limited to CI/CD use cases
- No rotation capabilities
- Not production-pattern aligned
- Doesn't teach cloud secrets management patterns

**Estimated Monthly Cost**: **$0.00/month**

**Note**: This is complementary rather than competitive—should be used alongside a proper secrets manager.

## Decision

**Selected Option: AWS Systems Manager Parameter Store (Standard Parameters with SecureString)**

## Rationale

AWS Systems Manager Parameter Store with Standard Parameters provides the optimal balance for a personal learning lab:

### Cost Justification
- **$0.00/month** for up to 10,000 standard parameters eliminates ongoing costs
- Even if scaling to advanced parameters, costs remain minimal ($0.05/parameter/month)
- API calls are negligible in learning environment usage patterns
- Allows budget to be allocated to other AWS services for learning

### Technical Alignment
- Provides production-grade patterns used in real enterprises
- Native AWS integration teaches valuable AWS-ecosystem skills
- Excellent Terraform support develops IaC competencies
- GitHub Actions integration via AWS OIDC demonstrates modern DevOps practices
- IAM policies provide hands-on experience with least-privilege access
- CloudTrail integration teaches audit logging patterns

### Learning Value
- Widely adopted in production environments (high career relevance)
- Foundation for understanding AWS Secrets Manager (easy upgrade path)
- Teaches parameter hierarchies and organization patterns
- Opportunity to implement custom secret rotation scripts (learning experience)
- Demonstrates cost-optimization decisions made in real businesses

### Practical Considerations
- Zero friction with existing AWS infrastructure
- Simple to implement and maintain
- Can scale to advanced parameters if needed
- Provides upgrade path to AWS Secrets Manager when rotation is needed
- Complements GitHub Secrets for CI/CD-specific credentials

## Implementation Strategy

### Phase 1: Foundation (Week 1)
1. Enable AWS Systems Manager in target regions
2. Create parameter naming convention (e.g., `/env/service/secret-name`)
3. Configure KMS keys for encryption
4. Set up IAM roles and policies for parameter access
5. Document parameter organization structure

### Phase 2: Terraform Integration (Week 1-2)
```hcl
# Example Terraform pattern
resource "aws_ssm_parameter" "db_password" {
  name  = "/dev/database/master_password"
  type  = "SecureString"
  value = var.db_password
  
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Reading parameters
data "aws_ssm_parameter" "db_password" {
  name = "/dev/database/master_password"
}
```

### Phase 3: GitHub Actions Integration (Week 2)
1. Configure AWS OIDC authentication for GitHub Actions
2. Create IAM role for GitHub Actions with SSM read permissions
3. Implement secret retrieval in workflows
```yaml
# Example GitHub Actions workflow
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-east-1

- name: Retrieve secrets
  run: |
    SECRET=$(aws ssm get-parameter --name /dev/api/key --with-decryption --query Parameter.Value --output text)
```

### Phase 4: Application Integration (Week 3)
1. Implement secret retrieval in application code (AWS SDK)
2. Add caching strategy to minimize API calls
3. Implement graceful failure handling
4. Document secret access patterns

### Phase 5: Operations & Best Practices (Week 4+)
1. Set up parameter expiration notifications
2. Implement manual rotation procedures
3. Create rotation runbook
4. Set up CloudTrail monitoring for parameter access
5. Document upgrade criteria for AWS Secrets Manager

## Migration Path

If automatic rotation or additional features become necessary:

1. **When to Migrate to AWS Secrets Manager**:
   - Need automatic secret rotation
   - Database credentials requiring frequent rotation
   - Compliance requirements emerge
   - Budget allows ($4-8/month becomes acceptable)

2. **Migration Approach**:
   - Terraform makes migration straightforward
   - Change resource type from `aws_ssm_parameter` to `aws_secretsmanager_secret`
   - Update IAM policies
   - Minimal application code changes (AWS SDK compatible)

## Consequences

### Positive
- Zero monthly costs for foreseeable usage
- Production-grade security patterns
- High learning value aligned with career goals
- Simple to implement and maintain
- Excellent integration with AWS ecosystem
- Foundation for future scaling
- Budget available for other AWS learning resources

### Negative
- Manual secret rotation implementation required (becomes learning opportunity)
- Need to implement custom rotation scripts if/when needed
- Size limitations (8 KB per parameter) may require creative solutions for large secrets
- No built-in complex rotation workflows

### Neutral
- Represents pragmatic cost-optimization decision common in startups/small teams
- Demonstrates understanding of "right-sizing" solutions
- Can revisit decision as requirements evolve

## Related Decisions
- **ADR-006**: KMS Key Management Strategy 
- **ADR-007**: IAM Policy Design for Parameter Store Access 
- **ADR-008**: Secret Rotation Implementation Patterns 

## References
- [AWS Systems Manager Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS Systems Manager Parameter Store Pricing](https://aws.amazon.com/systems-manager/pricing/)
- [Terraform AWS Provider - SSM Parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)
- [GitHub Actions - AWS Credentials Configuration](https://github.com/aws-actions/configure-aws-credentials)

## Review Schedule
- Initial review: After 3 months of usage
- Subsequent reviews: Every 6 months or when requirements change
- Triggers for immediate review:
  - Need for automatic rotation
  - Compliance requirements emerge
  - Multi-user collaboration begins
  - Budget constraints change

---

**Date**: 2025-10-31  
**Last Updated**: 2025-10-31  