# ADR-006: KMS Key Management Strategy

## Status
Accepted

## Context
Following the decision to use AWS Systems Manager Parameter Store for secrets management (ADR-005), we need to establish a comprehensive KMS (Key Management Service) key management strategy. While Parameter Store offers default encryption, using customer-managed KMS keys provides enhanced control, auditability, and the ability to implement fine-grained access policies.

### Requirements
- **Encryption at Rest**: All sensitive parameters must be encrypted
- **Access Control**: Fine-grained control over who can decrypt parameters
- **Auditability**: Track all encryption and decryption operations
- **Key Rotation**: Regular key rotation for security compliance
- **Cost Optimization**: Minimize KMS costs while maintaining security
- **Multi-Environment**: Support dev, staging, and production environments
- **Learning Value**: Align with enterprise KMS practices

### Current State
- Parameter Store supports both AWS-managed and customer-managed keys
- SecureString parameters can use either default AWS key or custom KMS keys
- KMS charges $1/month per customer-managed key + $0.03 per 10,000 API calls

### Constraints
- Learning lab budget requires cost optimization
- Single user/operator (simplified key policies)
- Must support GitHub Actions OIDC authentication
- Need to demonstrate production-ready patterns

## Decision Drivers
1. **Security**: Encryption strength and key management control
2. **Cost**: Monthly KMS key and API call costs
3. **Access Control**: Granular permissions for different roles/services
4. **Auditability**: CloudTrail logging and key usage monitoring
5. **Operational Overhead**: Key rotation and management complexity
6. **Separation of Concerns**: Environment and service isolation
7. **Learning Value**: Enterprise-grade patterns and best practices

## Options Considered

### Option 1: AWS-Managed Default Key (aws/ssm)
**Description**: Use the AWS-managed default key for SSM Parameter Store encryption.

**Pros**:
- **Zero cost**: No charges for AWS-managed keys
- Automatic key rotation every 3 years
- No key management overhead
- Immediate availability (no setup required)
- Works out of the box with Parameter Store

**Cons**:
- **Cannot customize key policies**: Limited control over access
- Cannot disable or delete the key
- Shared across all Parameter Store users in the account
- Less granular audit trails
- Cannot use cross-account access
- Limited learning value (doesn't teach KMS management)
- No control over rotation schedule

**Cost**: **$0/month**

### Option 2: Single Customer-Managed Key (All Environments)
**Description**: Create one customer-managed KMS key shared across all environments.

**Pros**:
- Low cost ($1/month total)
- Simple to manage (single key)
- Full control over key policy
- Automatic rotation can be enabled
- CloudTrail logging of key usage
- Can customize key administrators and users

**Cons**:
- **Security risk**: Compromise of one environment affects all
- **No environment isolation**: Dev can decrypt prod secrets
- Not production-grade pattern
- Violates separation of concerns
- Difficult to implement environment-specific access controls
- Single point of failure

**Cost**: **$1/month** + API calls

### Option 3: Per-Environment Customer-Managed Keys
**Description**: Create separate customer-managed KMS keys for each environment (dev, staging, prod).

**Pros**:
- **Strong environment isolation**: Dev key cannot decrypt prod secrets
- Independent key rotation schedules
- Environment-specific access controls
- Production-grade security pattern
- Easier compliance and auditing per environment
- Can disable/delete keys independently
- Matches enterprise practices
- Clear learning value

**Cons**:
- Higher cost ($1/month per environment)
- More keys to manage
- More complex key policies
- Multiple CloudTrail log streams to monitor

**Cost**: **$3/month** (dev + staging + prod) + API calls

### Option 4: Per-Service and Per-Environment Keys
**Description**: Create separate KMS keys for each service within each environment (e.g., database-dev, api-dev, app-dev).

**Pros**:
- Maximum isolation and security
- Finest-grained access control
- Service-level key rotation policies
- Excellent for large enterprises
- Clear separation of concerns

**Cons**:
- **High cost**: $1/month per key (potentially 15+ keys)
- Significant management overhead
- **Overkill for learning lab**: Too complex for single user
- Harder to understand initially
- More complex automation needed

**Cost**: **$15+/month** (5 services × 3 environments)

### Option 5: Hybrid Approach (AWS-Managed + Customer Keys for Critical)
**Description**: Use AWS-managed key for non-sensitive configs, customer-managed keys for sensitive secrets.

**Pros**:
- Cost optimization (fewer customer keys)
- Reduced management overhead
- Tiered security approach
- Flexibility

**Cons**:
- **Complexity**: Mixed approach harder to understand
- Need to classify parameters (sensitive vs non-sensitive)
- Inconsistent encryption strategy
- More error-prone
- Less clear for learning purposes

**Cost**: Variable ($0-3/month depending on sensitive secret count)

## Decision

**Selected Option: Option 3 - Per-Environment Customer-Managed Keys**

We will create separate customer-managed KMS keys for each environment (dev, staging, production).

## Rationale

### Security and Isolation
Per-environment keys provide the critical security boundary needed to prevent cross-environment access. This ensures:
- Developers with dev access cannot decrypt production secrets
- Compromise of dev key doesn't affect production
- Different rotation schedules for different risk levels
- Independent key policies per environment

### Cost Justification
At $3/month total ($1 per environment), the cost is:
- Minimal for the security benefit gained
- Still significantly less than Secrets Manager ($6.50/month)
- Reasonable for a learning lab that teaches production patterns
- Demonstrates real-world cost/security trade-offs

### Learning Value
This approach teaches:
- KMS key creation and management
- Key policy design
- Environment isolation patterns
- Key rotation strategies
- CloudTrail monitoring
- Real-world enterprise practices

### Production Alignment
Per-environment keys is the standard pattern in production:
- Used by small startups to large enterprises
- Recommended by AWS security best practices
- Common in compliance frameworks (SOC2, ISO 27001)
- Balances security and operational complexity

### Practical Considerations
- Three keys is manageable for a single operator
- Clear mental model (one key per environment)
- Easy to automate with Terraform
- Straightforward key policies

## Implementation Strategy

### Phase 1: KMS Key Creation

```hcl
# Create KMS key for each environment
resource "aws_kms_key" "parameter_store" {
  description             = "KMS key for Parameter Store encryption - ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true  # Automatic rotation enabled

  tags = {
    Environment = var.environment
    Purpose     = "ParameterStore"
    ManagedBy   = "Terraform"
  }
}

# Create alias for easy reference
resource "aws_kms_alias" "parameter_store" {
  name          = "alias/parameter-store-${var.environment}"
  target_key_id = aws_kms_key.parameter_store.key_id
}
```

### Phase 2: Key Policy Design

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow SSM to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "ssm.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow GitHub Actions for this environment",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:role/github-actions-ENV"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

### Phase 3: Parameter Store Integration

```hcl
# Create SecureString parameter with KMS key
resource "aws_ssm_parameter" "secure_secret" {
  name   = "/${var.environment}/database/password"
  type   = "SecureString"
  value  = var.db_password
  key_id = aws_kms_key.parameter_store.id  # Use environment-specific key
}
```

### Phase 4: IAM Permission Updates

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DecryptParameterStore",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": [
        "arn:aws:kms:REGION:ACCOUNT_ID:key/KEY_ID_FOR_THIS_ENV"
      ]
    }
  ]
}
```

### Phase 5: Monitoring and Auditing

```bash
# CloudTrail query for KMS key usage
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=KEY_ID \
  --max-results 50

# CloudWatch metric for decrypt operations
aws cloudwatch get-metric-statistics \
  --namespace AWS/KMS \
  --metric-name NumberOfDecryptOperations \
  --dimensions Name=KeyId,Value=KEY_ID \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

## Key Management Procedures

### Key Rotation Schedule

| Environment | Automatic Rotation | Manual Review | Key Policy Review |
|-------------|-------------------|---------------|-------------------|
| Development | Enabled (1 year) | Quarterly | Quarterly |
| Staging | Enabled (1 year) | Quarterly | Quarterly |
| Production | Enabled (1 year) | Monthly | Quarterly |

**Note**: AWS automatically rotates the cryptographic material while keeping the same key ID and ARN.

### Deletion Windows

| Environment | Deletion Window | Rationale |
|-------------|----------------|-----------|
| Development | 7 days | Fast iteration, low risk |
| Staging | 14 days | Balance of safety and speed |
| Production | 30 days | Maximum safety, reversibility |

### Key Policy Updates

Key policies should be reviewed and updated:
- When adding new services/roles
- When modifying environment access
- During quarterly security reviews
- After any security incidents
- When team members change

### Disaster Recovery

**Backup Strategy**:
- KMS keys cannot be exported or backed up
- Key deletion is logged in CloudTrail
- Parameters encrypted with deleted keys cannot be decrypted
- **Therefore**: Export and re-encrypt secrets before key deletion

**Recovery Procedure**:
```bash
# 1. Export all parameters before key deletion
aws ssm get-parameters-by-path \
  --path /${ENV} \
  --recursive \
  --with-decryption > backup.json

# 2. Create new KMS key
terraform apply

# 3. Re-encrypt all parameters with new key
# (Terraform will handle this automatically on next apply)
```

## Monitoring and Alerting

### CloudWatch Alarms

```hcl
# Alert on excessive decrypt operations
resource "aws_cloudwatch_metric_alarm" "kms_decrypt_rate" {
  alarm_name          = "kms-decrypt-high-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfDecryptOperations"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "Alert when decrypt operations exceed threshold"
  
  dimensions = {
    KeyId = aws_kms_key.parameter_store.id
  }
}
```

### Cost Monitoring

```bash
# Monthly KMS cost check
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --filter file://kms-filter.json \
  --metrics BlendedCost
```

## Consequences

### Positive
- **Strong Security**: Environment isolation prevents cross-environment access
- **Auditability**: CloudTrail provides complete audit trail
- **Compliance Ready**: Meets common compliance requirements (SOC2, ISO 27001)
- **Production Pattern**: Teaches real-world enterprise practices
- **Flexible**: Can add more keys or services as needed
- **Automatic Rotation**: Set-it-and-forget-it key rotation
- **Fine-Grained Control**: Environment-specific policies

### Negative
- **Cost**: $3/month for all environments (vs $0 for AWS-managed)
- **Management Overhead**: Three keys to monitor instead of one
- **Complexity**: More complex than single key or default key
- **API Costs**: Each decrypt operation charges (though minimal)

### Neutral
- **Learning Curve**: Requires understanding of KMS concepts
- **Terraform Complexity**: More resources to manage
- **CloudTrail Volume**: More events to filter through

### Mitigations
- **Cost**: $3/month is minimal and within learning lab budget
- **Management**: Terraform automates most management tasks
- **Complexity**: Well-documented and follows standard patterns
- **API Costs**: Caching in applications reduces decrypt calls

## Migration Path

### From AWS-Managed to Customer-Managed Keys

If starting with AWS-managed keys:

```bash
# 1. Create new KMS keys
terraform apply

# 2. Update parameters to use new key
aws ssm put-parameter \
  --name /dev/database/password \
  --value "$EXISTING_VALUE" \
  --type SecureString \
  --key-id $NEW_KEY_ID \
  --overwrite

# 3. Update IAM policies to allow KMS decrypt

# 4. Test access

# 5. Repeat for all parameters
```

### From Single Key to Per-Environment Keys

If starting with a single shared key:

```bash
# 1. Create environment-specific keys
terraform apply

# 2. Export parameters from each environment
aws ssm get-parameters-by-path --path /dev --recursive --with-decryption > dev-backup.json
aws ssm get-parameters-by-path --path /staging --recursive --with-decryption > staging-backup.json
aws ssm get-parameters-by-path --path /prod --recursive --with-decryption > prod-backup.json

# 3. Update Terraform to use environment-specific keys

# 4. Re-apply to encrypt with new keys
terraform apply

# 5. Update IAM policies

# 6. Test each environment

# 7. Decommission old shared key (after deletion window)
```

## Compliance Considerations

### SOC2 Requirements
- ✅ Encryption at rest (KMS provides)
- ✅ Key rotation (automatic annual rotation)
- ✅ Access controls (KMS key policies)
- ✅ Audit logging (CloudTrail)

### ISO 27001 Requirements
- ✅ Cryptographic controls (AWS KMS FIPS 140-2 Level 2)
- ✅ Key management (documented procedures)
- ✅ Separation of duties (environment isolation)
- ✅ Monitoring and logging (CloudWatch + CloudTrail)

### Best Practices Checklist
- ✅ Automatic key rotation enabled
- ✅ Deletion window configured (7-30 days)
- ✅ Key policies follow least privilege
- ✅ CloudTrail logging enabled
- ✅ CloudWatch alarms configured
- ✅ Regular policy reviews scheduled
- ✅ Disaster recovery procedures documented

## Cost Analysis

### Monthly Costs (Per Environment)

| Item | Cost | Notes |
|------|------|-------|
| KMS Key | $1.00 | Customer-managed key |
| Decrypt Operations | ~$0.01 | ~1,000 ops @ $0.03/10k |
| CloudTrail Logging | $0.00 | First trail free |
| **Total** | **~$1.00** | **Per environment** |

### Total Monthly Cost (All Environments)

| Environment | KMS Key | API Calls | Total |
|-------------|---------|-----------|-------|
| Dev | $1.00 | $0.01 | $1.01 |
| Staging | $1.00 | $0.005 | $1.005 |
| Prod | $1.00 | $0.005 | $1.005 |
| **Total** | **$3.00** | **$0.02** | **~$3.02** |

### Cost Optimization Strategies

1. **Reduce API Calls**:
   - Implement caching in applications
   - Batch parameter retrievals
   - Cache decrypted values (with TTL)

2. **Consolidate for Cost**:
   - If budget extremely tight, use single key
   - Trade security isolation for cost savings
   - Can upgrade later when needed

3. **Monitor Usage**:
   ```bash
   # Track decrypt operations
   aws cloudwatch get-metric-statistics \
     --namespace AWS/KMS \
     --metric-name NumberOfDecryptOperations
   ```

## Related Decisions
- **ADR-005**: Secret Management Solution Selection - Why Parameter Store
- **ADR-007**: IAM Policy Design - How roles access keys
- **ADR-008**: Secret Rotation Patterns - When to re-encrypt

## References
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS KMS Pricing](https://aws.amazon.com/kms/pricing/)
- [Parameter Store with KMS](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-securestring.html)
- [KMS Key Rotation](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)
- [CloudTrail with KMS](https://docs.aws.amazon.com/kms/latest/developerguide/logging-using-cloudtrail.html)

## Review Schedule
- **Initial Review**: After 3 months of operation
- **Regular Review**: Quarterly
- **Triggers for Immediate Review**:
  - Security incident
  - Compliance requirement changes
  - Budget constraints
  - Team size changes
  - New environment additions

---

**Date**: 2025-10-31  
**Last Updated**: 2025-10-31  
**Status**: Accepted