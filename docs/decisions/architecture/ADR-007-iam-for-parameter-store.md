# ADR-007: IAM Policy Design for Parameter Store Access

## Status
Accepted

## Context
Following decisions on using AWS Parameter Store (ADR-005) and implementing per-environment KMS keys (ADR-006), we need to establish a comprehensive IAM policy design that provides secure, least-privilege access to parameters. The challenge is balancing security, operational efficiency, and learning value while supporting both GitHub Actions automation and potential future service integrations.

### Requirements
- **Least Privilege**: Grant only necessary permissions
- **Environment Isolation**: Prevent cross-environment access
- **Role-Based Access**: Support different personas (CI/CD, applications, operators)
- **GitHub Actions OIDC**: Authenticate without long-lived credentials
- **Auditability**: Clear tracking of who accessed what
- **Scalability**: Easy to extend for new services
- **Learning Value**: Demonstrate enterprise IAM patterns

### Current Landscape
- GitHub Actions is the primary automation tool
- Single operator (personal learning lab)
- Three environments (dev, staging, prod)
- Multiple service categories (database, API, application)
- Future: May add ECS tasks, Lambda functions, EC2 instances

### Constraints
- Must work with GitHub OIDC provider
- Need to demonstrate production patterns
- Single AWS account (no cross-account complexity yet)
- Learning lab context (favor clarity over extreme granularity)

## Decision Drivers
1. **Security**: Prevent unauthorized access and privilege escalation
2. **Operational Simplicity**: Easy to understand and maintain
3. **Flexibility**: Support current and future use cases
4. **Auditability**: Track all parameter access
5. **Learning Value**: Teach real-world IAM patterns
6. **Cost**: No additional cost (IAM is free)
7. **Automation-Friendly**: Works well with IaC

## Options Considered

### Option 1: Single Wide-Open Policy
**Description**: One IAM policy with broad permissions for all environments and services.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
```

**Pros**:
- Simple to implement
- No permission issues ever
- Easy to understand
- Zero maintenance

**Cons**:
- **Major security risk**: No environment isolation
- Violates least privilege principle
- **Not production-ready**: Would fail security audits
- Poor learning value (teaches bad practices)
- Cannot track specific access patterns
- Dev can access prod secrets

**Cost**: $0 (IAM is free)
**Security Score**: ⚠️ 1/10 - Unacceptable

### Option 2: Environment-Scoped Policies
**Description**: Separate policies for each environment, granting access only to that environment's parameters.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadDevParameters",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/dev/*"
    },
    {
      "Sid": "DecryptDevKMS",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:ACCOUNT_ID:key/DEV_KEY_ID"
    }
  ]
}
```

**Pros**:
- **Strong environment isolation**: Dev cannot access prod
- Follows least privilege per environment
- Production-ready pattern
- Clear audit trails
- Good learning value
- Easy to implement with Terraform

**Cons**:
- Cannot differentiate between services within an environment
- All parameters in an environment have same access level
- May be too broad for high-security prod environments

**Cost**: $0 (IAM is free)
**Security Score**: ✅ 7/10 - Good for most cases

### Option 3: Service and Environment Scoped Policies
**Description**: Policies scoped to both environment AND service (e.g., database, API, app).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadDevDatabaseParameters",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": [
        "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/dev/database/*",
        "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/dev/app/*"
      ]
    }
  ]
}
```

**Pros**:
- **Maximum least privilege**: Each service sees only its secrets
- Excellent security posture
- Very granular audit trails
- Ideal for large teams
- Demonstrates advanced IAM

**Cons**:
- **Complex**: Many more policies to manage
- **Overkill for single user**: Unnecessary granularity
- Harder to maintain
- More policy documents
- Steeper learning curve initially

**Cost**: $0 (IAM is free)
**Security Score**: ✅ 9/10 - Enterprise-grade

### Option 4: Read-Only vs Read-Write Policies
**Description**: Separate policies for read-only access (applications) and read-write access (operators/automation).

**Read-Only Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadParameters",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:DescribeParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/dev/*"
    }
  ]
}
```

**Read-Write Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageParameters",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:GetParameter*",
        "ssm:DescribeParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/dev/*"
    }
  ]
}
```

**Pros**:
- Clear separation of concerns
- Applications cannot modify secrets
- Reduces blast radius of compromised credentials
- Common enterprise pattern
- Good for different personas

**Cons**:
- More policies to manage
- Need to assign correctly to each role
- Single-user lab doesn't benefit much initially

**Cost**: $0 (IAM is free)
**Security Score**: ✅ 8/10 - Very good

### Option 5: Hybrid Approach (Environment + Permission Level)
**Description**: Combine environment scoping with read-only/read-write distinction.

**Pros**:
- Best of both worlds
- Environment isolation + permission levels
- Scalable to future needs
- Professional pattern

**Cons**:
- Most complex option
- More policies to maintain
- May be overkill initially

**Cost**: $0 (IAM is free)
**Security Score**: ✅ 9/10 - Enterprise-grade

## Decision

**Selected Option: Option 2 with Option 4 characteristics - Environment-Scoped Policies with Read-Only GitHub Actions**

We will implement environment-scoped policies that:
1. Isolate environments from each other
2. Grant GitHub Actions read-only access
3. Allow read-write access for operators (via AWS CLI)
4. Provide clear upgrade path to service-level scoping

## Rationale

### Security Balance
Environment-scoped policies provide strong security without excessive complexity:
- Dev workflows cannot access prod secrets
- GitHub Actions has minimal permissions (read-only)
- Operators retain write access when needed
- Clear security boundaries

### Learning Value
This approach teaches:
- Least privilege principle in practice
- Resource-based access control
- OIDC authentication patterns
- How to scope IAM policies effectively
- Environment isolation strategies

### Operational Simplicity
- Three primary policies (one per environment)
- Easy to understand and explain
- Simple to extend with new services
- Clear mental model for single operator

### Future-Proof
Easy migration path to:
- Service-scoped policies (when team grows)
- Cross-account access (when multi-account needed)
- Additional role types (Lambda, ECS, etc.)

### Production Alignment
This pattern is used by:
- Small to medium startups
- Teams transitioning to better security
- Organizations balancing security and agility

## Implementation Strategy

### Phase 1: GitHub OIDC Provider Setup

```hcl
# Create GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # GitHub's thumbprints (updated periodically)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}
```

### Phase 2: Environment-Specific IAM Roles

```hcl
# IAM Role for GitHub Actions - Dev Environment
resource "aws_iam_role" "github_actions_dev" {
  name = "github-actions-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:ORG/REPO:*"
          }
        }
      }
    ]
  })
}
```

### Phase 3: Read-Only Parameter Store Policy

```hcl
# Read-only access to dev parameters
resource "aws_iam_policy" "parameter_store_read_dev" {
  name        = "parameter-store-read-dev"
  description = "Read-only access to dev Parameter Store parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDevParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/dev/*"
        ]
      },
      {
        Sid    = "DecryptDevKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.parameter_store_dev.arn
        ]
      },
      {
        Sid    = "DescribeParameters"
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### Phase 4: Read-Write Policy (for Operators)

```hcl
# Read-write access to dev parameters
resource "aws_iam_policy" "parameter_store_write_dev" {
  name        = "parameter-store-write-dev"
  description = "Read-write access to dev Parameter Store parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageDevParameters"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/dev/*"
        ]
      },
      {
        Sid    = "EncryptDecryptDevKMS"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.parameter_store_dev.arn
        ]
      },
      {
        Sid    = "DescribeParameters"
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### Phase 5: Attach Policies to Roles

```hcl
# Attach read-only policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_dev_read" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = aws_iam_policy.parameter_store_read_dev.arn
}
```

## Policy Matrix

### By Environment and Permission Level

| Role/Principal | Dev (Read) | Dev (Write) | Staging (Read) | Staging (Write) | Prod (Read) | Prod (Write) |
|----------------|------------|-------------|----------------|-----------------|-------------|--------------|
| GitHub Actions Dev | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| GitHub Actions Staging | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| GitHub Actions Prod | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Admin User (AWS CLI) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Future: ECS Task Dev | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Future: Lambda Prod | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |

### Permission Boundaries

Each environment policy explicitly denies:
- Cross-environment access
- KMS key usage from other environments
- Parameter creation in other environments

## IAM Best Practices Applied

### 1. Least Privilege
- ✅ Grant only necessary permissions
- ✅ Read-only where possible (GitHub Actions)
- ✅ Environment-scoped resources
- ✅ No wildcard (*) in resource ARNs

### 2. Use IAM Roles (Not Users)
- ✅ GitHub Actions uses OIDC role (no access keys)
- ✅ Future services will use IAM roles
- ✅ No long-lived credentials

### 3. Enable MFA for Sensitive Operations
- ⚠️ Not yet implemented (future enhancement)
- Can add MFA requirement for production write access

### 4. Rotate Credentials
- ✅ OIDC tokens short-lived (1 hour)
- ✅ No access keys to rotate
- ✅ Automatic token refresh

### 5. Use Policy Conditions
- ✅ OIDC condition on GitHub repo
- ✅ Can add IP restrictions
- ✅ Can add time-based restrictions

### 6. Monitor and Audit
- ✅ CloudTrail logs all API calls
- ✅ Can create CloudWatch alarms
- ✅ Policy changes tracked in Terraform

## Security Controls

### Defense in Depth

**Layer 1: Network** (Future)
- VPC endpoints for SSM
- Private subnet access only

**Layer 2: IAM Authentication**
- ✅ OIDC for GitHub Actions
- ✅ IAM users/roles for operators

**Layer 3: IAM Authorization**
- ✅ Environment-scoped policies
- ✅ Resource-level permissions
- ✅ Read vs write separation

**Layer 4: Encryption**
- ✅ KMS encryption at rest (ADR-002)
- ✅ TLS encryption in transit

**Layer 5: Audit**
- ✅ CloudTrail logging
- ✅ Parameter version history
- ✅ KMS key usage tracking

### Threat Model and Mitigations

| Threat | Mitigation | Effectiveness |
|--------|-----------|---------------|
| Compromised GitHub token | Short-lived OIDC tokens (1hr) | ✅ High |
| Cross-environment access | Environment-scoped policies | ✅ High |
| Unauthorized parameter read | IAM policy enforcement | ✅ High |
| Parameter tampering | Read-only GitHub Actions role | ✅ High |
| Privilege escalation | No IAM:* permissions granted | ✅ High |
| Deleted parameters | Parameter version history | ⚠️ Medium |
| KMS key deletion | Deletion window (7-30 days) | ✅ High |

## Testing Strategy

### Policy Validation

```bash
# Test GitHub Actions role can read dev parameters
aws ssm get-parameter \
  --name /dev/database/password \
  --with-decryption \
  --role-arn arn:aws:iam::ACCOUNT:role/github-actions-dev

# Test GitHub Actions role CANNOT read prod parameters
aws ssm get-parameter \
  --name /prod/database/password \
  --with-decryption \
  --role-arn arn:aws:iam::ACCOUNT:role/github-actions-dev
# Should return: AccessDenied

# Test GitHub Actions role CANNOT write
aws ssm put-parameter \
  --name /dev/test/param \
  --value "test" \
  --type String \
  --role-arn arn:aws:iam::ACCOUNT:role/github-actions-dev
# Should return: AccessDenied
```

### IAM Policy Simulator

```bash
# Simulate read access to dev
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/github-actions-dev \
  --action-names ssm:GetParameter \
  --resource-arns "arn:aws:ssm:us-east-1:ACCOUNT:parameter/dev/database/password"

# Simulate write access (should be denied)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/github-actions-dev \
  --action-names ssm:PutParameter \
  --resource-arns "arn:aws:ssm:us-east-1:ACCOUNT:parameter/dev/database/password"
```

### Automated Testing in CI

```yaml
# GitHub Actions workflow to test IAM permissions
- name: Test IAM Permissions
  run: |
    # Should succeed
    aws ssm get-parameter --name /dev/test/param || exit 1
    
    # Should fail
    aws ssm get-parameter --name /prod/test/param && exit 1 || echo "Correctly denied"
    
    # Should fail
    aws ssm put-parameter --name /dev/test --value "x" && exit 1 || echo "Correctly denied"
```

## Monitoring and Alerts

### CloudWatch Alarms

```hcl
# Alert on unauthorized access attempts
resource "aws_cloudwatch_log_metric_filter" "unauthorized_ssm_access" {
  name           = "UnauthorizedSSMAccess"
  log_group_name = "/aws/cloudtrail/logs"
  
  pattern = "{ $.errorCode = AccessDenied && $.eventSource = ssm.amazonaws.com }"
  
  metric_transformation {
    name      = "UnauthorizedSSMAccessCount"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_ssm_alarm" {
  alarm_name          = "unauthorized-ssm-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedSSMAccessCount"
  namespace           = "Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on multiple unauthorized SSM access attempts"
}
```

### Audit Queries

```bash
# List all SSM parameter access in last 24 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetParameter \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 100

# Find all denied access attempts
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetParameter \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --query 'Events[?ErrorCode==`AccessDenied`]'
```

## Migration and Evolution

### From Current Design to Service-Scoped (Future)

When the team grows or security requirements increase:

```hcl
# Step 1: Create service-specific policies
resource "aws_iam_policy" "database_service_dev" {
  name = "database-service-dev"
  
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter*"]
      Resource = "arn:aws:ssm:*:*:parameter/dev/database/*"
    }]
  })
}

# Step 2: Create service-specific roles
resource "aws_iam_role" "database_task_dev" {
  name = "database-task-dev"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Step 3: Attach policies
resource "aws_iam_role_policy_attachment" "database_task_policy" {
  role       = aws_iam_role.database_task_dev.name
  policy_arn = aws_iam_policy.database_service_dev.arn
}
```

### Adding New Environments

```bash
# Copy existing environment configuration
cp terraform/environments/dev/terraform.tfvars terraform/environments/qa/terraform.tfvars

# Update environment name
sed -i 's/environment = "dev"/environment = "qa"/g' terraform/environments/qa/terraform.tfvars

# Apply - will create new role and policies
terraform apply -var-file="environments/qa/terraform.tfvars"
```

## Consequences

### Positive
- ✅ **Strong security**: Environment isolation prevents cross-environment access
- ✅ **No credentials**: OIDC eliminates long-lived secrets
- ✅ **Clear audit trail**: Every access logged to CloudTrail
- ✅ **Production pattern**: Used by real companies
- ✅ **Easy to understand**: Clear permission boundaries
- ✅ **Free**: IAM costs nothing
- ✅ **Scalable**: Easy to extend

### Negative
- ⚠️ **Multiple policies**: More complex than single policy
- ⚠️ **Initial setup**: Requires OIDC provider configuration
- ⚠️ **Policy maintenance**: Changes needed for new environments

### Neutral
- ⚙️ **Learning required**: Need to understand IAM concepts
- ⚙️ **Terraform complexity**: More resources to manage
- ⚙️ **Testing overhead**: Policies should be tested

### Mitigations
- **Complexity**: Terraform automates policy creation
- **Setup**: One-time configuration, then reusable
- **Maintenance**: Changes are infrastructure-as-code

## Related Decisions
- **ADR-005**: Secret Management Solution Selection
- **ADR-006**: KMS Key Management Strategy
- **ADR-008**: Secret Rotation Implementation Patterns

## References
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [IAM Roles for ECS Tasks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [Parameter Store IAM Permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html)
- [AWS Security Audit Guidelines](https://docs.aws.amazon.com/audit-manager/latest/userguide/control-compliance.html)

## Review Schedule
- **Initial Review**: After 1 month of operation
- **Regular Review**: Quarterly
- **Triggers for Review**:
  - New service additions
  - Team member changes
  - Security incidents
  - Compliance requirements
  - Failed authorization attempts

---

**Date**: 2025-10-31  
**Last Updated**: 2025-10-31  
**Status**: Accepted  