# ADR-005: Selection of Cloud-Based Secrets Manager Service

## Status

Approved

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

**Selected Option #1:** AWS Secrets Manager

## Rationale

AWS Secrets Manager provides the optimal balance for a personal learning lab focused on Infrastructure as Code (IaC) and automation-first practices:

### IaC and Automation Justification

- **Native secret generation**: Secrets Manager can auto-generate secure random secrets via Terraform, eliminating manual value creation
- **Automatic rotation**: Built-in rotation for RDS, DocumentDB, Redshift eliminates custom Lambda development
- **No click-ops required**: Entire secret lifecycle can be managed through Terraform without AWS Console access
- **CloudFormation/Terraform native support**: Full SecureString support without workarounds needed by Parameter Store
- **Version management**: Automatic versioning without manual implementation
- **Recovery windows**: Deleted secrets can be recovered (7-30 day window), preventing accidental data loss

### Technical Alignment

- Industry-standard solution for production secrets management
- Native AWS integration with RDS, ECS, Lambda, and other services
- Built-in audit logging via CloudTrail (no additional configuration needed)
- Fine-grained IAM access control
- Excellent Terraform support via AWS provider
- GitHub Actions has mature AWS authentication (OIDC)

### Cost-Benefit Analysis

- **Estimated cost**: $4-8/month for 10-20 secrets (acceptable for learning investment)
- **Time savings**: Eliminates need to implement custom rotation logic
- **Reduced operational overhead**: Automation reduces manual secret management tasks
- **Hybrid approach**: Limit secrets in Secrets Manager; use Kubernetes-native secrets management (e.g., Sealed Secrets, External Secrets Operator) for application secrets within K8s clusters

### Learning Value

- Most relevant for enterprise/production patterns
- Demonstrates proper separation of infrastructure and application secrets
- Teaches secret rotation best practices without reinventing the wheel
- Provides experience with AWS managed service automation
- Better career alignment with production-grade secrets management

### Practical Considerations

- Reduced time spent on custom tooling allows focus on other learning areas
- Built-in features reduce potential for security misconfigurations
- Cleaner IaC codebase without rotation boilerplate
- Better integration story for future microservices/containerized workloads

## Implementation Strategy

### Phase 1: Foundation (Week 1)

1. Enable AWS Secrets Manager in target regions
2. Create secret naming convention (e.g., `env/service/secret-name`)
3. Configure dedicated KMS keys for encryption (one per environment recommended)
4. Set up IAM roles and policies for Secrets Manager access
5. Document secret organization structure and tagging strategy

### Phase 2: Terraform Integration (Week 1-2)

```hcl
# Example Terraform pattern - Auto-generated secret
resource "aws_secretsmanager_secret" "db_master_password" {
  name                    = "dev/database/master_password"
  description             = "Master password for dev database"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.id

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Service     = "rds"
  }
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = aws_secretsmanager_secret.db_master_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_master.result
  })
}

resource "random_password" "db_master" {
  length  = 32
  special = true
}

# Reading secrets in Terraform
data "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = "dev/database/master_password"
}

# Example with automatic rotation for RDS
resource "aws_secretsmanager_secret_rotation" "db_master_password" {
  secret_id           = aws_secretsmanager_secret.db_master_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Phase 3: GitHub Actions Integration (Week 2)

1. Configure AWS OIDC authentication for GitHub Actions
2. Create IAM role for GitHub Actions with Secrets Manager read permissions
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
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id dev/api/key \
      --query SecretString \
      --output text)
```

### Phase 4: Kubernetes Integration (Week 2-3)

1. Evaluate and implement External Secrets Operator (ESO) for K8s cluster
2. Configure SecretStore to connect K8s to AWS Secrets Manager
3. Create ExternalSecret resources that sync from AWS to K8s
4. Document which secrets live in AWS (infrastructure) vs K8s (application)

```yaml
# Example External Secrets Operator configuration
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-db-secret
  data:
  - secretKey: username
    remoteRef:
      key: dev/app/database
      property: username
  - secretKey: password
    remoteRef:
      key: dev/app/database
      property: password
```

### Phase 5: Application Integration (Week 3)

1. Implement secret retrieval in application code (AWS SDK)
2. Consider caching strategy for frequently accessed secrets (optional with Secrets Manager)
3. Implement graceful failure handling
4. Document secret access patterns

### Phase 6: Operations & Best Practices (Week 4+)

1. Enable automatic rotation for database credentials
2. Set up CloudWatch alarms for rotation failures
3. Configure secret expiration notifications
4. Establish secret lifecycle management procedures
5. Document secret organization and access patterns

## Future Evolution Path

### Kubernetes-Native Secrets Management

As the Kubernetes workload grows, consider shifting more application-level secrets to K8s-native solutions:

1. **When to Move Secrets to K8s-Native Management**:
   - Application secrets that don't need AWS service integration
   - Service-to-service authentication tokens within cluster
   - Configuration that changes per deployment/namespace
   - Secrets that benefit from K8s RBAC instead of IAM

2. **K8s Secret Management Options**:
   - **External Secrets Operator (ESO)**: Sync from AWS Secrets Manager to K8s (hybrid approach)
   - **Sealed Secrets**: GitOps-friendly encrypted secrets stored in Git
   - **Vault (on K8s)**: Full-featured secrets management within cluster
   - **SOPS**: Encrypted secrets in Git using AWS KMS

3. **Recommended Hybrid Strategy**:
   - **AWS Secrets Manager**: Infrastructure secrets (RDS, AWS service credentials, cross-service auth)
   - **K8s External Secrets**: Application secrets synced from Secrets Manager
   - **K8s Native Secrets**: Non-sensitive configuration, temporary tokens
   - **Sealed Secrets**: Development environment secrets in GitOps workflow

### Parameter Store for Non-Secret Configuration

Consider using Parameter Store alongside Secrets Manager for:

- Non-sensitive configuration values (feature flags, endpoints, etc.)
- Large configuration files (using S3 with Parameter Store references)
- Hierarchical configuration that benefits from Parameter Store's path structure
- Configuration that changes frequently and doesn't need rotation

This hybrid approach optimizes cost while maintaining separation between secrets and configuration.

## Consequences

### Positive

- **Automation-first approach**: No manual secret generation or rotation logic required
- **Production-grade patterns**: Industry-standard solution used in enterprise environments
- **IaC excellence**: Entire secret lifecycle managed through Terraform without console access
- **Reduced operational overhead**: Built-in features eliminate custom tooling development
- **Better time allocation**: More time for learning other AWS services vs. building rotation logic
- **Hybrid capability**: Easy integration with Kubernetes via External Secrets Operator
- **Recovery protection**: 7-30 day recovery window prevents accidental permanent deletion
- **Career relevance**: Direct experience with most common enterprise secrets management solution

### Negative

- **Monthly cost**: ~$4-8/month for 10-20 secrets (vs. $0 for Parameter Store)
- **Cost scales linearly**: Each additional secret costs $0.40/month
- **API call costs**: $0.05 per 10,000 API calls (typically minimal but accumulates with high usage)
- **Annual cost**: ~$50-100/year for moderate usage

### Neutral

- **Cost mitigation via K8s**: Using K8s-native solutions for application secrets limits Secrets Manager usage
- **Cost vs. time trade-off**: Paying for automation allows focus on higher-value learning
- **Hybrid strategy enables optimization**: Can use Parameter Store for non-sensitive configuration
- **Demonstrates production decision-making**: Choosing managed services over DIY reflects modern DevOps practices

## Known Limitations and Challenges

Based on production usage patterns and industry experience, the following limitations and challenges should be considered when implementing AWS Secrets Manager:

### Cost Considerations

#### 1. Per-Secret Monthly Cost

- $0.40 per secret per month (no free tier beyond 30-day trial)
- Cost scales linearly with number of secrets
- 50 secrets = $20/month = $240/year
- Mitigation: Use K8s-native solutions for application secrets; reserve Secrets Manager for infrastructure secrets

#### 2. API Call Costs

- $0.05 per 10,000 API calls
- High-frequency access can accumulate costs
- Mitigation: Implement caching in applications (AWS SDKs have built-in caching support)

### Operational Challenges

#### 3. No Hierarchical Storage

- Unlike Parameter Store, Secrets Manager doesn't support path-based hierarchies
- Must use naming conventions and tags for organization
- Cannot browse secrets in a tree structure
- Mitigation: Establish clear naming conventions (e.g., `env-service-secret-name`) and comprehensive tagging strategy

#### 4. Secret Size Limits

- 65,536 bytes (64 KB) maximum per secret
- Larger than Parameter Store but still limited
- Mitigation: For very large secrets, use S3 with encryption and store reference in Secrets Manager

#### 5. Rotation Lambda Complexity

- Automatic rotation requires Lambda functions
- Built-in rotation only for specific AWS services (RDS, DocumentDB, Redshift)
- Custom rotation logic needed for third-party services
- Mitigation: Use AWS-provided rotation Lambda templates as starting point for custom rotations

#### 6. No Cross-Region Replication (Native)

- Secrets are region-specific by default
- Multi-region applications need secrets duplicated per region
- Secrets Manager provides replication feature but requires explicit configuration
- Mitigation: Use Secrets Manager replication feature or Terraform to maintain consistency across regions

### Security & Permissions

#### 7. IAM and KMS Permission Requirements

- Requires both IAM permissions (`secretsmanager:GetSecretValue`) AND KMS permissions (`kms:Decrypt`)
- Resource policies add another layer of complexity
- Common source of access denied errors
- Mitigation: Use IAM policy templates and document permission patterns (see ADR-007)

#### 8. Secret Name Visibility

- Secret names, descriptions, and tags are not encrypted
- Only secret values are encrypted
- Secret names appear in CloudTrail logs
- Mitigation: Avoid including sensitive information in secret names; use generic naming patterns

#### 9. Recovery Window Constraints

- Minimum 7-day recovery window for deletion
- Cannot immediately delete secrets (can force delete but not recommended)
- Deleted secrets with pending deletion can't be recreated with same name
- Mitigation: Plan secret naming strategy to avoid conflicts; use `force_delete` in Terraform only for dev environments

### Performance Considerations

#### 10. API Latency

- Each retrieval hits AWS API (network latency)
- Multi-region setups may have increased latency
- First retrieval in cold-start scenarios can be slow
- Mitigation: Implement caching (AWS SDKs support built-in caching); pre-fetch secrets during application startup

#### 11. Rotation Downtime Windows

- Secret rotation may cause brief unavailability
- Applications must handle secret updates gracefully
- Multi-user secrets (database with many clients) need careful rotation coordination
- Mitigation: Implement retry logic; use staging labels (AWSCURRENT, AWSPENDING) to handle transitions

### Integration Challenges

#### 12. Terraform State Contains Secret Metadata

- Secret values not stored in state, but metadata is
- Secret ARNs and names visible in Terraform state
- Mitigation: Use remote state with encryption; restrict access to state files

### Best Practices to Mitigate Issues

1. **Implement Caching**: Use AWS SDK built-in caching or implement application-level caching (5-15 minute TTL)
2. **Clear Naming Conventions**: Use consistent, non-sensitive naming patterns (e.g., `env-service-type-version`)
3. **Comprehensive Tagging**: Tag all secrets with Environment, Service, ManagedBy, CostCenter for organization and cost tracking
4. **Dedicated KMS Keys**: Create separate KMS keys per environment (dev, staging, prod) for access control
5. **IAM Policy Templates**: Create reusable IAM policies for common access patterns
6. **Secret Versioning Strategy**: Use version stages (AWSCURRENT, AWSPENDING) appropriately in applications
7. **Monitoring and Alerts**: Set up CloudWatch alarms for rotation failures and access patterns
8. **Cost Monitoring**: Tag secrets and track costs; regularly audit unused secrets
9. **Hybrid Approach**: Use Parameter Store for non-sensitive configuration to reduce costs
10. **K8s Integration**: Leverage External Secrets Operator to sync to K8s, avoiding direct API calls from pods

### Comparison: Secrets Manager vs Parameter Store

For reference, here's when to use each service:

**Use AWS Secrets Manager for:**

- Database credentials requiring automatic rotation
- Secrets that change frequently and need version tracking
- Infrastructure secrets requiring recovery windows
- Secrets needing cross-region replication
- When automation and reduced operational overhead justify the cost

**Use Parameter Store for:**

- Non-sensitive configuration values
- Static configuration that rarely changes
- Cost-sensitive environments
- Large number of configuration parameters (10,000 free standard parameters)
- When building custom rotation logic is acceptable

**Hybrid Approach (Recommended):**

- **Secrets Manager**: Infrastructure secrets (RDS, AWS service credentials)
- **Parameter Store**: Non-sensitive configuration, application settings, feature flags
- **K8s Secrets**: Application-level secrets synced from Secrets Manager via External Secrets Operator
- **K8s ConfigMaps**: Non-sensitive application configuration

## Related Decisions

- **ADR-006**: KMS Key Management Strategy (encryption keys for secrets)
- **ADR-007**: IAM Policy Design for Secrets Manager Access (least-privilege access patterns)
- **ADR-008**: Kubernetes Secrets Management Strategy (K8s-native vs AWS Secrets Manager)
- **ADR-009**: External Secrets Operator Implementation (syncing AWS secrets to K8s)

## References

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [AWS Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [Terraform AWS Provider - Secrets Manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)
- [AWS Secrets Manager Rotation Lambda Templates](https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas)
- [External Secrets Operator Documentation](https://external-secrets.io/)
- [GitHub Actions - AWS Credentials Configuration](https://github.com/aws-actions/configure-aws-credentials)
- [AWS SDK Secrets Manager Caching](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets.html)

## Review Schedule

- Initial review: After 3 months of usage
- Subsequent reviews: Every 6 months or when requirements change
- Triggers for immediate review:
  - Monthly costs exceed $15
  - Kubernetes adoption increases significantly (evaluate K8s-native solutions)
  - Need for multi-region disaster recovery
  - Compliance requirements emerge
  - Multi-user collaboration begins

---

**Date**: 2025-10-31
**Last Updated**: 2025-11-17 (Changed decision from Parameter Store to Secrets Manager)
