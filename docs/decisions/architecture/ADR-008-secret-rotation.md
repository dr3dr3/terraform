# ADR-008: Secret Rotation Implementation Patterns

## Status
Accepted

## Context
Following decisions on Parameter Store (ADR-005), KMS encryption (ADR-006), and IAM policies (ADR-007), we need to establish comprehensive secret rotation patterns. Unlike AWS Secrets Manager which provides automatic rotation for certain secret types, Parameter Store requires manual implementation of rotation logic. This presents both a challenge and a learning opportunity to understand rotation mechanics deeply.

### Requirements
- **Regular Rotation**: Secrets should be rotated periodically
- **Zero Downtime**: Applications continue working during rotation
- **Automation**: Minimize manual intervention
- **Multiple Secret Types**: Database passwords, API keys, application secrets
- **Audit Trail**: Track when secrets were rotated
- **Rollback Capability**: Revert if rotation causes issues
- **Cost Effective**: Leverage free/low-cost solutions
- **Learning Value**: Understand rotation mechanics

### Current State
- Parameter Store stores secrets but doesn't rotate them automatically
- Manual rotation requires updating parameter and dependent services
- No built-in coordination between secret update and service restart
- Version history provides rollback capability (up to 100 versions)

### Constraints
- Learning lab budget (must be cost-effective)
- Single operator (automation is valuable)
- Various secret types with different rotation requirements
- Some services may need restart after rotation

## Decision Drivers
1. **Security**: Reduce blast radius of compromised credentials
2. **Automation**: Minimize manual intervention
3. **Reliability**: Ensure applications continue working
4. **Complexity**: Balance sophistication with maintainability
5. **Cost**: Leverage free tier and minimize expenses
6. **Learning Value**: Understand rotation mechanics deeply
7. **Production Readiness**: Demonstrate enterprise patterns

## Options Considered

### Option 1: Manual Rotation (No Automation)
**Description**: Operator manually updates secrets and restarts services as needed.

**Process**:
1. Generate new secret value
2. Update parameter via AWS CLI
3. Manually restart dependent services
4. Update documentation

**Pros**:
- Simple to understand
- No automation code needed
- Zero cost
- Full control over timing

**Cons**:
- **Error-prone**: Easy to forget steps
- **Time-consuming**: Manual work every rotation
- **Not scalable**: Doesn't work with many secrets
- **Poor learning value**: Doesn't teach automation
- **Not production-ready**: Companies automate this

**Cost**: $0
**Security Score**: ⚠️ 3/10 - Easy to skip rotations

### Option 2: Scheduled GitHub Actions Workflow
**Description**: GitHub Actions workflow runs on schedule to rotate secrets automatically.

**Process**:
1. Workflow triggers on schedule (e.g., weekly)
2. Python script generates new secret values
3. Updates parameters via AWS API
4. Optionally triggers service restarts
5. Creates report/notification

**Pros**:
- **Free**: GitHub Actions free tier
- Version controlled workflow
- Audit trail in GitHub
- Easy to modify and extend
- Can run on-demand or scheduled
- Good learning value
- Demonstrates CI/CD patterns

**Cons**:
- Requires GitHub Actions knowledge
- Limited to GitHub ecosystem
- No built-in error handling beyond workflow
- Notifications require additional setup

**Cost**: $0 (GitHub Actions free tier)
**Security Score**: ✅ 7/10 - Good automation

### Option 3: AWS Lambda with EventBridge
**Description**: Lambda function triggered by EventBridge (CloudWatch Events) to rotate secrets.

**Process**:
1. EventBridge rule triggers Lambda on schedule
2. Lambda generates new secrets
3. Lambda updates parameters
4. Lambda triggers service updates
5. Lambda sends SNS notification

**Pros**:
- Native AWS integration
- Can trigger service-specific updates
- SNS for notifications
- CloudWatch for logging
- More production-like
- Can respond to events

**Cons**:
- **Costs money**: Lambda invocations + EventBridge rules
- More complex infrastructure
- Requires Lambda knowledge
- Need to package dependencies
- Additional IAM complexity

**Cost**: ~$1-2/month (Lambda + EventBridge)
**Security Score**: ✅ 8/10 - Enterprise pattern

### Option 4: Hybrid (GitHub Actions + Service-Specific Scripts)
**Description**: GitHub Actions for scheduled rotation, service-specific scripts for coordination.

**Process**:
1. GitHub Actions triggers on schedule
2. Calls service-specific rotation scripts
3. Each script handles its secret type differently
4. Database rotation: update password + update connection
5. API key rotation: dual-key pattern with grace period
6. Application secret rotation: rolling restart

**Pros**:
- **Flexible**: Different strategies per secret type
- Free (GitHub Actions)
- Reusable scripts
- Good for complex scenarios
- Excellent learning value
- Production-ready patterns

**Cons**:
- Most complex implementation
- Requires careful coordination
- More code to maintain
- Needs thorough testing

**Cost**: $0 (GitHub Actions free tier)
**Security Score**: ✅ 9/10 - Sophisticated

### Option 5: External Tools (HashiCorp Vault Rotation)
**Description**: Use external rotation tools like Vault's rotation engines.

**Pros**:
- Battle-tested rotation logic
- Professional-grade
- Many integrations

**Cons**:
- **Requires running Vault**: Self-hosted (against requirements)
- Or Vault Cloud (costs money)
- Additional complexity
- Overkill for learning lab

**Cost**: $0 (self-hosted) or $0.03/hour (cloud) = ~$22/month
**Security Score**: ✅ 10/10 - Enterprise

## Decision

**Selected Option: Option 4 - Hybrid GitHub Actions with Service-Specific Rotation Strategies**

We will implement automated rotation using GitHub Actions with different rotation strategies for different secret types:
1. **Simple Secrets**: Direct replacement (application secrets, JWT keys)
2. **Database Credentials**: Coordinated update with connection refresh
3. **API Keys**: Dual-key pattern with grace period
4. **Certificates**: Renewal and deployment pipeline

## Rationale

### Learning Value
This approach provides deep understanding of:
- How rotation actually works (not black box)
- Different strategies for different secret types
- Coordination challenges
- Zero-downtime deployment patterns
- Error handling and rollback

### Cost Effective
- GitHub Actions free tier (2,000 minutes/month)
- No Lambda or EventBridge costs
- No external service subscriptions
- All code is open and maintainable

### Production Ready
These patterns are used by real companies:
- Netflix uses similar coordination patterns
- Stripe uses dual-key rotation for API keys
- Major SaaS companies use these strategies

### Flexibility
Easy to extend:
- Add new secret types
- Customize rotation frequency
- Implement additional notifications
- Integrate with monitoring

## Implementation Strategy

### Phase 1: Infrastructure Setup

**GitHub Actions Workflow**:
```yaml
name: Secret Rotation

on:
  schedule:
    # Run every Monday at 2 AM UTC
    - cron: '0 2 * * 1'
  workflow_dispatch:
    inputs:
      secret_type:
        description: 'Type of secret to rotate'
        type: choice
        options:
          - all
          - database
          - api-keys
          - app-secrets

permissions:
  id-token: write
  contents: read

jobs:
  rotate-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROTATION_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install boto3 cryptography
      
      - name: Rotate secrets
        run: python scripts/rotate_secrets.py
        env:
          ENVIRONMENT: ${{ inputs.environment || 'dev' }}
          SECRET_TYPE: ${{ inputs.secret_type || 'all' }}
```

### Phase 2: Rotation Script Architecture

```python
# scripts/rotate_secrets.py
import boto3
import secrets
import string
from datetime import datetime, timedelta
from typing import Dict, List
import logging

class SecretRotator:
    def __init__(self, environment: str, region: str = 'us-east-1'):
        self.environment = environment
        self.ssm = boto3.client('ssm', region_name=region)
        self.logger = logging.getLogger(__name__)
    
    def rotate_all(self):
        """Rotate all secrets based on their type"""
        self.rotate_application_secrets()
        self.rotate_database_credentials()
        self.rotate_api_keys()
    
    def rotate_application_secrets(self):
        """Simple rotation for application secrets"""
        secrets_to_rotate = [
            'app/jwt-secret',
            'app/encryption-key',
            'app/session-secret'
        ]
        
        for secret_name in secrets_to_rotate:
            new_value = self.generate_strong_secret(64)
            self.update_parameter(secret_name, new_value)
            self.logger.info(f"Rotated {secret_name}")
    
    def rotate_database_credentials(self):
        """Coordinated database credential rotation"""
        # Step 1: Get current password
        current_password = self.get_parameter('database/password')
        
        # Step 2: Generate new password
        new_password = self.generate_strong_secret(32)
        
        # Step 3: Update database user password
        self.update_database_password(new_password)
        
        # Step 4: Update parameter
        self.update_parameter('database/password', new_password)
        
        # Step 5: Verify connectivity
        self.verify_database_connection()
        
        # Step 6: Trigger application restart
        self.trigger_service_restart('database')
    
    def rotate_api_keys(self):
        """Dual-key rotation for API keys"""
        # Implement dual-key pattern
        # See detailed implementation below
        pass
    
    def generate_strong_secret(self, length: int) -> str:
        """Generate cryptographically strong secret"""
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def update_parameter(self, name: str, value: str):
        """Update SSM parameter"""
        full_name = f"/{self.environment}/{name}"
        self.ssm.put_parameter(
            Name=full_name,
            Value=value,
            Type='SecureString',
            Overwrite=True,
            Description=f"Rotated on {datetime.now().isoformat()}"
        )
```

### Phase 3: Secret Type Specific Strategies

#### Strategy A: Simple Application Secrets
**Use Case**: JWT secrets, encryption keys, session secrets

**Characteristics**:
- Used internally by application
- All instances can adopt immediately
- No external coordination needed

**Rotation Steps**:
1. Generate new secret value
2. Update parameter
3. Restart application instances (rolling restart)
4. Verify application health

**Zero-Downtime Pattern**:
```python
def rotate_application_secret(self, secret_name: str):
    """Simple rotation with rolling restart"""
    # 1. Generate new value
    new_value = self.generate_strong_secret(64)
    
    # 2. Update parameter
    self.update_parameter(secret_name, new_value)
    
    # 3. Rolling restart (assuming ECS)
    # New tasks will pick up new secret
    ecs = boto3.client('ecs')
    ecs.update_service(
        cluster='my-cluster',
        service='my-service',
        forceNewDeployment=True
    )
    
    # 4. Wait for deployment to complete
    self.wait_for_deployment('my-service')
```

#### Strategy B: Database Credentials
**Use Case**: RDS passwords, database user credentials

**Characteristics**:
- External system (database) needs updating
- Application needs to reconnect
- Coordination required

**Rotation Steps**:
1. Get current credentials
2. Generate new password
3. Update database user password first
4. Update parameter
5. Trigger connection pool refresh
6. Verify connectivity

**Zero-Downtime Pattern**:
```python
def rotate_database_credentials(self):
    """Coordinated database rotation"""
    # 1. Get database connection info
    db_host = self.get_parameter('database/host')
    db_user = self.get_parameter('database/username')
    current_password = self.get_parameter('database/password')
    
    # 2. Generate new password
    new_password = self.generate_strong_secret(32)
    
    # 3. Update password in database
    import psycopg2
    conn = psycopg2.connect(
        host=db_host,
        user=db_user,
        password=current_password
    )
    cursor = conn.cursor()
    cursor.execute(
        f"ALTER USER {db_user} WITH PASSWORD %s",
        (new_password,)
    )
    conn.commit()
    conn.close()
    
    # 4. Update parameter
    self.update_parameter('database/password', new_password)
    
    # 5. Trigger application restart
    # Applications will reconnect with new password
    self.trigger_service_restart('api')
    
    # 6. Verify new credentials work
    test_conn = psycopg2.connect(
        host=db_host,
        user=db_user,
        password=new_password
    )
    test_conn.close()
```

#### Strategy C: API Keys (Dual-Key Pattern)
**Use Case**: External API keys (OpenAI, Stripe, etc.)

**Characteristics**:
- Used by external services
- Cannot force immediate adoption
- Need grace period for transition

**Rotation Steps**:
1. Create new API key in external service
2. Store as secondary key
3. Grace period (both keys work)
4. Switch primary to new key
5. Deprecate old key
6. Delete old key after grace period

**Zero-Downtime Pattern**:
```python
def rotate_api_key_dual_pattern(self, service_name: str):
    """Dual-key rotation with grace period"""
    # 1. Get current primary key
    primary_key = self.get_parameter(f'api/{service_name}/key')
    
    # 2. Check if secondary exists (in rotation)
    try:
        secondary_key = self.get_parameter(f'api/{service_name}/key-secondary')
        in_rotation = True
    except:
        in_rotation = False
    
    if not in_rotation:
        # Start rotation: create secondary key
        new_key = self.create_external_api_key(service_name)
        self.update_parameter(f'api/{service_name}/key-secondary', new_key)
        
        # Set grace period end
        grace_period_end = datetime.now() + timedelta(days=7)
        self.update_parameter(
            f'api/{service_name}/grace-period-end',
            grace_period_end.isoformat()
        )
        
        self.logger.info(f"Started rotation for {service_name}. Grace period: 7 days")
    else:
        # Complete rotation: promote secondary to primary
        grace_period_end = self.get_parameter(f'api/{service_name}/grace-period-end')
        
        if datetime.now() > datetime.fromisoformat(grace_period_end):
            # Grace period over, complete rotation
            self.update_parameter(f'api/{service_name}/key', secondary_key)
            self.delete_external_api_key(service_name, primary_key)
            self.ssm.delete_parameter(Name=f'api/{service_name}/key-secondary')
            
            self.logger.info(f"Completed rotation for {service_name}")
        else:
            self.logger.info(f"Still in grace period for {service_name}")
```

#### Strategy D: Certificates
**Use Case**: TLS certificates, SSL certs

**Characteristics**:
- Have expiration dates
- Need renewal before expiry
- Deployment can be complex

**Rotation Steps**:
1. Check cert expiration (rotate 30 days before)
2. Generate new certificate
3. Store new cert
4. Deploy to services
5. Verify deployment
6. Delete old cert after grace period

### Phase 4: Service Coordination

```python
def trigger_service_restart(self, service_name: str):
    """Trigger restart of dependent services"""
    ecs = boto3.client('ecs')
    
    # Map service names to ECS services
    service_map = {
        'database': ['api-service', 'worker-service'],
        'api': ['api-service'],
        'app': ['api-service', 'web-service']
    }
    
    services_to_restart = service_map.get(service_name, [])
    
    for ecs_service in services_to_restart:
        self.logger.info(f"Restarting {ecs_service}")
        ecs.update_service(
            cluster='my-cluster',
            service=ecs_service,
            forceNewDeployment=True
        )
```

### Phase 5: Verification and Rollback

```python
def verify_rotation(self, secret_name: str) -> bool:
    """Verify secret rotation was successful"""
    try:
        # Get new secret
        new_value = self.get_parameter(secret_name)
        
        # Verify it's different from previous version
        param_history = self.ssm.get_parameter_history(
            Name=f"/{self.environment}/{secret_name}",
            MaxResults=2
        )
        
        if len(param_history['Parameters']) < 2:
            return True  # First version
        
        previous_value = param_history['Parameters'][1]['Value']
        
        return new_value != previous_value
    except Exception as e:
        self.logger.error(f"Verification failed: {e}")
        return False

def rollback_rotation(self, secret_name: str):
    """Rollback to previous secret version"""
    param_history = self.ssm.get_parameter_history(
        Name=f"/{self.environment}/{secret_name}",
        MaxResults=2
    )
    
    if len(param_history['Parameters']) < 2:
        raise Exception("No previous version to rollback to")
    
    previous_value = param_history['Parameters'][1]['Value']
    
    self.ssm.put_parameter(
        Name=f"/{self.environment}/{secret_name}",
        Value=previous_value,
        Type='SecureString',
        Overwrite=True,
        Description=f"Rolled back on {datetime.now().isoformat()}"
    )
    
    self.logger.info(f"Rolled back {secret_name} to previous version")
```

## Rotation Schedule

### By Secret Type

| Secret Type | Rotation Frequency | Strategy | Grace Period |
|-------------|-------------------|----------|--------------|
| Database Passwords | 90 days | Coordinated | None |
| Application Secrets | 90 days | Simple | None |
| JWT Secrets | 180 days | Simple | None |
| API Keys (External) | Manual | Dual-key | 7 days |
| Certificates | 60 days before expiry | Renewal | 30 days |
| SSH Keys | 365 days | Manual | N/A |

### By Environment

| Environment | Auto-Rotation | Manual Review | Emergency Rotation |
|-------------|--------------|---------------|-------------------|
| Development | Yes (60 days) | Quarterly | As needed |
| Staging | Yes (90 days) | Monthly | As needed |
| Production | Yes (90 days) | Monthly | Immediate |

## Monitoring and Alerting

### Rotation Metrics

```python
def record_rotation_metrics(self, secret_name: str, success: bool):
    """Record rotation metrics to CloudWatch"""
    cloudwatch = boto3.client('cloudwatch')
    
    cloudwatch.put_metric_data(
        Namespace='SecretRotation',
        MetricData=[
            {
                'MetricName': 'RotationSuccess',
                'Value': 1 if success else 0,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'Environment', 'Value': self.environment},
                    {'Name': 'SecretName', 'Value': secret_name}
                ]
            }
        ]
    )
```

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "rotation_failures" {
  alarm_name          = "secret-rotation-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RotationSuccess"
  namespace           = "SecretRotation"
  period              = "86400"  # 24 hours
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on secret rotation failures"
  treat_missing_data  = "notBreaching"
}
```

### Notifications

```python
def send_rotation_report(self, results: Dict[str, bool]):
    """Send rotation report"""
    sns = boto3.client('sns')
    
    total = len(results)
    succeeded = sum(1 for v in results.values() if v)
    failed = total - succeeded
    
    message = f"""
    Secret Rotation Report - {self.environment}
    
    Date: {datetime.now().isoformat()}
    Total Secrets: {total}
    Successful: {succeeded}
    Failed: {failed}
    
    Details:
    """
    
    for secret, success in results.items():
        status = "✅ SUCCESS" if success else "❌ FAILED"
        message += f"\n{secret}: {status}"
    
    sns.publish(
        TopicArn='arn:aws:sns:region:account:rotation-notifications',
        Subject=f'Secret Rotation Report - {self.environment}',
        Message=message
    )
```

## Testing Strategy

### Unit Tests

```python
import unittest
from unittest.mock import Mock, patch

class TestSecretRotation(unittest.TestCase):
    def setUp(self):
        self.rotator = SecretRotator('test')
    
    def test_generate_strong_secret(self):
        secret = self.rotator.generate_strong_secret(32)
        self.assertEqual(len(secret), 32)
        self.assertTrue(any(c.isupper() for c in secret))
        self.assertTrue(any(c.islower() for c in secret))
        self.assertTrue(any(c.isdigit() for c in secret))
    
    @patch('boto3.client')
    def test_update_parameter(self, mock_boto):
        mock_ssm = Mock()
        mock_boto.return_value = mock_ssm
        
        self.rotator.update_parameter('test/secret', 'new_value')
        
        mock_ssm.put_parameter.assert_called_once()
    
    def test_verify_rotation(self):
        # Test verification logic
        pass
```

### Integration Tests

```python
def test_full_rotation_workflow():
    """Test complete rotation workflow in test environment"""
    rotator = SecretRotator('test')
    
    # Create test secret
    original_value = rotator.generate_strong_secret(32)
    rotator.update_parameter('test/rotation-test', original_value)
    
    # Rotate secret
    rotator.rotate_application_secret('test/rotation-test')
    
    # Verify rotation
    new_value = rotator.get_parameter('test/rotation-test')
    assert new_value != original_value
    
    # Verify old value is in history
    history = rotator.ssm.get_parameter_history(
        Name='/test/test/rotation-test',
        MaxResults=2
    )
    assert len(history['Parameters']) == 2
```

### Dry-Run Mode

```python
class SecretRotator:
    def __init__(self, environment: str, dry_run: bool = False):
        self.environment = environment
        self.dry_run = dry_run
        self.ssm = boto3.client('ssm')
    
    def update_parameter(self, name: str, value: str):
        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would update {name}")
            return
        
        # Actual update logic
        full_name = f"/{self.environment}/{name}"
        self.ssm.put_parameter(...)
```

## Disaster Recovery

### Backup Before Rotation

```python
def backup_before_rotation(self, secret_names: List[str]) -> str:
    """Backup secrets before rotation"""
    backup_data = {}
    
    for secret_name in secret_names:
        value = self.get_parameter(secret_name)
        backup_data[secret_name] = value
    
    # Save to S3
    s3 = boto3.client('s3')
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_key = f"secret-backups/{self.environment}/{timestamp}.json.encrypted"
    
    # Encrypt backup (using KMS)
    import json
    backup_json = json.dumps(backup_data)
    
    s3.put_object(
        Bucket='my-backups-bucket',
        Key=backup_key,
        Body=backup_json,
        ServerSideEncryption='aws:kms'
    )
    
    return backup_key
```

### Recovery Procedure

```bash
# 1. List available backups
aws s3 ls s3://my-backups-bucket/secret-backups/dev/

# 2. Download backup
aws s3 cp s3://my-backups-bucket/secret-backups/dev/20251031-120000.json.encrypted /tmp/backup.json

# 3. Restore secrets
python scripts/restore_secrets.py --backup /tmp/backup.json --environment dev

# 4. Verify restoration
./scripts/secrets.sh validate -e dev

# 5. Restart services
python scripts/restart_services.py --environment dev
```

## Age-Based Rotation Check

```python
def check_secrets_age(self) -> List[str]:
    """Check which secrets are due for rotation"""
    secrets_to_rotate = []
    max_age_days = 90
    
    # Get all parameters
    params = self.ssm.describe_parameters(
        ParameterFilters=[
            {
                'Key': 'Name',
                'Option': 'BeginsWith',
                'Values': [f'/{self.environment}/']
            }
        ]
    )
    
    for param in params['Parameters']:
        # Check last modified date
        last_modified = param['LastModifiedDate']
        age = (datetime.now(last_modified.tzinfo) - last_modified).days
        
        if age >= max_age_days:
            secrets_to_rotate.append(param['Name'])
            self.logger.warning(
                f"{param['Name']} is {age} days old (threshold: {max_age_days})"
            )
    
    return secrets_to_rotate
```

## Consequences

### Positive
- ✅ **Automated**: Secrets rotate automatically
- ✅ **Free**: Uses GitHub Actions free tier
- ✅ **Flexible**: Different strategies per secret type
- ✅ **Learning**: Deep understanding of rotation mechanics
- ✅ **Production-Ready**: Enterprise patterns
- ✅ **Auditable**: Complete trail in GitHub and CloudTrail
- ✅ **Rollback**: Can revert to previous versions
- ✅ **Zero-Downtime**: Applications continue working

### Negative
- ⚠️ **Complexity**: More code to maintain than AWS Secrets Manager auto-rotation
- ⚠️ **Manual for Some**: API keys still require manual intervention
- ⚠️ **Testing**: Need comprehensive test coverage
- ⚠️ **Coordination**: Database rotation requires careful sequencing

### Neutral
- ⚙️ **GitHub-Dependent**: Relies on GitHub Actions
- ⚙️ **Learning Curve**: Need to understand each strategy
- ⚙️ **Service-Specific**: Some patterns need customization

### Mitigations
- **Complexity**: Well-documented code with examples
- **Manual Work**: Clear procedures and checklists
- **Testing**: Comprehensive test suite provided
- **Coordination**: Detailed coordination patterns documented

## Migration to AWS Secrets Manager (Future)

If automatic rotation becomes a requirement:

```python
# 1. Create Secrets Manager secret
aws secretsmanager create-secret \
  --name /prod/database/password \
  --secret-string "current_value" \
  --kms-key-id <key-id>

# 2. Set up rotation
aws secretsmanager rotate-secret \
  --secret-id /prod/database/password \
  --rotation-lambda-arn <lambda-arn> \
  --rotation-rules AutomaticallyAfterDays=30

# 3. Update application to use Secrets Manager API
# 4. Migrate one environment at a time
# 5. Decommission Parameter Store parameters
```

## Related Decisions
- **ADR-005**: Secret Management Solution Selection
- **ADR-006**: KMS Key Management Strategy
- **ADR-007**: IAM Policy Design

## References
- [AWS Secrets Rotation Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [Database Credential Rotation](https://aws.amazon.com/blogs/security/how-to-rotate-amazon-rds-database-credentials-with-aws-secrets-manager/)
- [API Key Rotation Patterns](https://stripe.com/docs/keys#api-key-rotation)
- [Zero-Downtime Deployments](https://aws.amazon.com/blogs/compute/blue-green-deployments-with-amazon-ecs/)
- [Parameter Store Version History](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-versions.html)

## Review Schedule
- **Initial Review**: After first automated rotation
- **Regular Review**: Monthly for first 3 months, then quarterly
- **Triggers for Review**:
  - Rotation failures
  - Service outages during rotation
  - New service types requiring rotation
  - Team feedback

---
 
**Date**: 2025-10-31  
**Last Updated**: 2025-10-31  
**Status**: Accepted  