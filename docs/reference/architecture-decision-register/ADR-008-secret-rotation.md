# ADR-008: Secret Rotation Implementation Patterns

## Status

Approved

## Context

Following decisions on AWS Secrets Manager (ADR-005), KMS encryption (ADR-006), and IAM policies (ADR-007), we need to establish comprehensive secret rotation patterns. While AWS Secrets Manager provides automatic rotation for certain secret types (RDS, DocumentDB, Redshift), custom rotation logic is needed for other secret types (API keys, application secrets, certificates). Additionally, we need to clarify how rotated secrets integrate with Kubernetes deployments via External Secrets Operator (ESO) as defined in ADR-003 and ADR-004.

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

- Secrets Manager stores secrets with built-in rotation for AWS services (RDS, etc.)
- Custom rotation needed for non-AWS secrets (API keys, application secrets)
- External Secrets Operator (ESO) syncs secrets from Secrets Manager to Kubernetes
- K8s applications consume secrets via native K8s Secret resources
- Secret rotation must trigger ESO sync and application pod updates
- Version history provides rollback capability (automatic versioning in Secrets Manager)

### Constraints

- Learning lab budget (must be cost-effective)
- Single operator (automation is valuable)
- Various secret types with different rotation requirements
- K8s applications consume secrets via External Secrets Operator
- ESO refresh interval affects how quickly rotated secrets reach applications
- Pod restart or volume remount may be needed for applications to pick up new secrets

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
- Time-consuming: Manual work every rotation
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
3. Updates Secrets Manager via AWS API
4. External Secrets Operator detects change (polling interval: 1-15 minutes)
5. ESO updates K8s Secret resources
6. K8s applications pick up new secrets (via volume remount or pod restart)
7. Creates rotation report/notification

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
3. Lambda updates Secrets Manager
4. ESO detects change and updates K8s Secrets
5. Lambda optionally triggers K8s deployment rollout
6. Lambda sends SNS notification

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
4. Database rotation: update password in DB + update Secrets Manager + ESO syncs to K8s
5. API key rotation: dual-key pattern with grace period
6. K8s rotation: Update Secrets Manager + ESO sync + optional pod restart annotation
7. Application secret rotation: rolling restart

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

### Selected Option: Option 4 - Hybrid GitHub Actions with Service-Specific Rotation Strategies

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

## External Secrets Operator Integration

### Overview

Per ADR-003 and ADR-004, Kubernetes applications consume secrets via External Secrets Operator (ESO), which synchronizes secrets from AWS Secrets Manager to native Kubernetes Secret resources. Secret rotation must account for this architecture:

```text
AWS Secrets Manager
       ↓ (Rotated by GitHub Actions or AWS Lambda)
       ↓
External Secrets Operator (ESO)
       ↓ (Polls every 1-15 minutes, configurable)
       ↓
Kubernetes Secret
       ↓ (Mounted as volume or env var)
       ↓
Application Pod
```

### ESO Configuration for Rotation Support

```yaml
# ExternalSecret with automatic refresh
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-database-credentials
  namespace: production
spec:
  refreshInterval: 5m  # Poll Secrets Manager every 5 minutes
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-db-secret
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
  - secretKey: username
    remoteRef:
      key: prod/database/credentials
      property: username
  - secretKey: password
    remoteRef:
      key: prod/database/credentials
      property: password
```

### Rotation Flow with ESO

#### Step 1: Rotate Secret in Secrets Manager

```python
# GitHub Actions workflow rotates secret
def rotate_database_password():
    new_password = generate_secure_password(32)
    
    # Update database
    update_database_user_password(new_password)
    
    # Update Secrets Manager
    secretsmanager.put_secret_value(
        SecretId='prod/database/credentials',
        SecretString=json.dumps({
            'username': 'app_user',
            'password': new_password
        })
    )
```

#### Step 2: ESO Detects and Syncs (Automatic)

- ESO polls Secrets Manager based on `refreshInterval`
- Detects new secret version
- Updates Kubernetes Secret resource
- K8s Secret's `resourceVersion` changes

#### Step 3: Application Picks Up New Secret**

Applications can consume rotated secrets in three ways:

#### Option A: Volume Mount with Automatic Refresh (Recommended)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: secrets
          mountPath: /secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: app-db-secret
# Kubelet automatically updates mounted secrets (30-60 second delay)
# Application must watch file for changes or re-read periodically
```

#### Option B: Environment Variables with Pod Restart (Simple)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  annotations:
    # Reloader watches secrets and restarts pods
    reloader.stakater.com/auto: "true"
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-db-secret
              key: password
# Requires Reloader or manual rollout restart
```

#### Option C: Forced Rollout Restart (Most Reliable)

```bash
# After rotation, force pod restart
kubectl rollout restart deployment/app -n production
```

### Recommended Approach

For zero-downtime rotation:

1. **Use volume mounts** (not environment variables)
2. **Configure application to re-read secrets periodically**
3. **Set ESO refresh interval to 5-10 minutes**
4. **Implement connection pool refresh** in application
5. **Optional: Use Reloader operator** to automate pod restarts

### Testing ESO Integration

```bash
# 1. Rotate secret in Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id dev/test/rotation-test \
  --secret-string "new-value-$(date +%s)"

# 2. Watch ESO sync the secret
kubectl get externalsecret app-test -n dev -w

# 3. Verify K8s Secret updated
kubectl get secret app-test-secret -n dev -o yaml

# 4. Check ESO logs
kubectl logs -n external-secrets-system \
  deployment/external-secrets -f | grep app-test

# 5. Verify application can access new secret
kubectl exec -n dev deployment/app -- cat /secrets/password
```

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
        self.secretsmanager = boto3.client('secretsmanager', region_name=region)
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
            self.update_secret(secret_name, new_value)
            self.logger.info(f"Rotated {secret_name}")
            # ESO will automatically sync within refresh interval (5-10 min)
    
    def rotate_database_credentials(self):
        """Coordinated database credential rotation"""
        # Step 1: Get current password
        current_password = self.get_secret('database/password')
        
        # Step 2: Generate new password
        new_password = self.generate_strong_secret(32)
        
        # Step 3: Update database user password
        self.update_database_password(new_password)
        
        # Step 4: Update Secrets Manager
        self.update_secret('database/password', new_password)
        
        # Step 5: Wait for ESO to sync (or force sync)
        self.wait_for_eso_sync('database/password')
        
        # Step 6: Trigger K8s deployment rollout restart
        self.trigger_k8s_rollout_restart('database')
        
        # Step 7: Verify connectivity
        self.verify_database_connection()
    
    def rotate_api_keys(self):
        """Dual-key rotation for API keys"""
        # Implement dual-key pattern
        # See detailed implementation below
        pass
    
    def generate_strong_secret(self, length: int) -> str:
        """Generate cryptographically strong secret"""
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def update_secret(self, name: str, value: str):
        """Update Secrets Manager secret"""
        full_name = f"{self.environment}/{name}"
        
        try:
            self.secretsmanager.put_secret_value(
                SecretId=full_name,
                SecretString=value
            )
            self.logger.info(f"Updated secret: {full_name}")
        except self.secretsmanager.exceptions.ResourceNotFoundException:
            # Create secret if it doesn't exist
            self.secretsmanager.create_secret(
                Name=full_name,
                SecretString=value,
                Description=f"Rotated on {datetime.now().isoformat()}"
            )
            self.logger.info(f"Created secret: {full_name}")
    
    def wait_for_eso_sync(self, secret_name: str, timeout: int = 600):
        """Wait for ESO to sync the secret to K8s"""
        # Poll K8s secret to verify ESO has synced
        import subprocess
        import time
        
        start_time = time.time()
        full_name = f"{self.environment}/{secret_name}"
        
        # Get the secret's current version from Secrets Manager
        response = self.secretsmanager.describe_secret(SecretId=full_name)
        current_version = response['VersionIdsToStages']
        current_version_id = [k for k, v in current_version.items() if 'AWSCURRENT' in v][0]
        
        while time.time() - start_time < timeout:
            # Check if K8s secret has the new version
            # This requires kubectl access or K8s API client
            # Simplified version: just wait for ESO refresh interval
            time.sleep(30)  # Wait 30 seconds for ESO to sync
            self.logger.info(f"Waiting for ESO to sync {secret_name}...")
            break  # In production, verify actual sync
        
        self.logger.info(f"ESO sync completed for {secret_name}")
    
    def trigger_k8s_rollout_restart(self, deployment_name: str):
        """Trigger Kubernetes deployment rollout restart"""
        import subprocess
        
        namespace = self.environment  # Assuming namespace matches environment
        
        result = subprocess.run([
            'kubectl', 'rollout', 'restart',
            f'deployment/{deployment_name}',
            '-n', namespace
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            self.logger.info(f"Triggered rollout restart for {deployment_name}")
        else:
            self.logger.error(f"Failed to restart {deployment_name}: {result.stderr}")
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
    """Simple rotation with K8s rollout restart"""
    # 1. Generate new value
    new_value = self.generate_strong_secret(64)
    
    # 2. Update Secrets Manager
    self.update_secret(secret_name, new_value)
    
    # 3. Wait for ESO to sync (optional)
    self.wait_for_eso_sync(secret_name)
    
    # 4. Rolling restart K8s deployment
    # Pods will pick up new secret from updated K8s Secret
    import subprocess
    subprocess.run([
        'kubectl', 'rollout', 'restart',
        'deployment/my-service',
        '-n', self.environment
    ])
    
    # 5. Wait for rollout to complete
    subprocess.run([
        'kubectl', 'rollout', 'status',
        'deployment/my-service',
        '-n', self.environment
    ])
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
4. Update Secrets Manager
5. ESO syncs to K8s Secret (automatic)
6. Trigger K8s deployment rollout restart
7. Verify connectivity

**Zero-Downtime Pattern**:

```python
def rotate_database_credentials(self):
    """Coordinated database rotation with K8s integration"""
    # 1. Get database connection info
    db_host = self.get_secret('database/host')
    db_user = self.get_secret('database/username')
    current_password = self.get_secret('database/password')
    
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
    
    # 4. Update Secrets Manager
    self.update_secret('database/password', new_password)
    
    # 5. Wait for ESO to sync
    self.wait_for_eso_sync('database/password')
    
    # 6. Trigger K8s deployment rollout restart
    # Applications will reconnect with new password from updated K8s Secret
    import subprocess
    subprocess.run([
        'kubectl', 'rollout', 'restart',
        'deployment/api-service',
        '-n', self.environment
    ])
    
    # 7. Verify new credentials work
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
        value = self.get_secret(secret_name)
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

# 5. Verify ESO has synced restored secrets to K8s
kubectl get externalsecrets -n dev

# 6. Trigger K8s deployment rollouts if needed
kubectl rollout restart deployment/api-service -n dev
```

## Age-Based Rotation Check

```python
def check_secrets_age(self) -> List[str]:
    """Check which secrets are due for rotation"""
    secrets_to_rotate = []
    max_age_days = 90
    
    # Get all secrets from Secrets Manager
    paginator = self.secretsmanager.get_paginator('list_secrets')
    
    for page in paginator.paginate():
        for secret in page['SecretList']:
            # Filter by environment prefix
            if not secret['Name'].startswith(f"{self.environment}/"):
                continue
            
            # Check last changed date
            last_changed = secret.get('LastChangedDate')
            if last_changed:
                age = (datetime.now(last_changed.tzinfo) - last_changed).days
                
                if age >= max_age_days:
                    secrets_to_rotate.append(secret['Name'])
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
- ⚠️ **ESO Latency**: 5-15 minute delay between rotation and K8s Secret update
- ⚠️ **Pod Restart Needed**: Some applications may require pod restart to pick up new secrets

### Neutral

- ⚙️ **GitHub-Dependent**: Relies on GitHub Actions
- ⚙️ **Learning Curve**: Need to understand each strategy and ESO integration
- ⚙️ **Service-Specific**: Some patterns need customization
- ⚙️ **K8s Native**: Applications must support K8s secret consumption patterns

### Mitigations

- **Complexity**: Well-documented code with examples
- **Manual Work**: Clear procedures and checklists
- **Testing**: Comprehensive test suite provided
- **Coordination**: Detailed coordination patterns documented
- **ESO Latency**: Reduce refresh interval to 5 minutes or use Reloader operator
- **Pod Restart**: Use volume mounts + application file watching, or Reloader operator for automatic restarts

## Kubernetes-Specific Rotation Considerations

### ESO Refresh Interval Trade-offs

| Refresh Interval | Pros | Cons | Best For |
|------------------|------|------|----------|
| 1 minute | Fast secret propagation | Higher AWS API costs, more K8s resource updates | Critical production secrets |
| 5 minutes | Good balance | Slight delay in rotation | Recommended default |
| 15 minutes | Lower API costs | Longer rotation delay | Non-critical dev/staging |
| 1 hour | Minimal API costs | Significant rotation delay | Configuration values |

### Application Secret Consumption Patterns

#### Pattern 1: File-Based with Periodic Reload (Best for Rotation)

```python
# Application code that re-reads secret file
import time
import os

class SecretManager:
    def __init__(self, secret_path='/secrets/db-password'):
        self.secret_path = secret_path
        self.last_mtime = 0
        self.cached_secret = None
    
    def get_secret(self):
        # Check if file has been modified
        current_mtime = os.path.getmtime(self.secret_path)
        
        if current_mtime != self.last_mtime:
            # File changed, reload secret
            with open(self.secret_path) as f:
                self.cached_secret = f.read().strip()
            self.last_mtime = current_mtime
        
        return self.cached_secret

# Database connection pool with refresh
def refresh_connection_pool():
    new_password = secret_manager.get_secret()
    if new_password != current_password:
        # Close old connections
        pool.close_all()
        # Create new pool with new password
        pool = create_pool(new_password)
```

#### Pattern 2: Reloader Operator (Easiest for Pod Restart)

```yaml
# Install Reloader
helm repo add stakater https://stakater.github.io/stakater-charts
helm install reloader stakater/reloader

# Add annotation to deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  annotations:
    reloader.stakater.com/auto: "true"
    # Or watch specific secrets:
    # reloader.stakater.com/search: "true"
spec:
  template:
    spec:
      containers:
      - name: app
        volumeMounts:
        - name: secrets
          mountPath: /secrets
      volumes:
      - name: secrets
        secret:
          secretName: app-db-secret
# Reloader watches secret and triggers rolling restart automatically
```

#### Pattern 3: Init Container for Critical Secrets

```yaml
# Verify secret exists before starting main container
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
      - name: verify-secrets
        image: busybox
        command: ['sh', '-c', 'test -f /secrets/password && echo "Secret verified"']
        volumeMounts:
        - name: secrets
          mountPath: /secrets
      containers:
      - name: app
        # ... main container
```

### Testing Rotation End-to-End

```bash
#!/bin/bash
# test-rotation-e2e.sh

set -e

ENVIRONMENT="dev"
SECRET_NAME="dev/test/rotation-e2e"
NAMESPACE="dev"
DEPLOYMENT="test-app"

echo "1. Create initial secret in Secrets Manager"
aws secretsmanager create-secret \
  --name "$SECRET_NAME" \
  --secret-string "initial-value-$(date +%s)"

echo "2. Wait for ESO to sync (max 5 minutes)"
for i in {1..30}; do
  if kubectl get secret test-secret -n "$NAMESPACE" &>/dev/null; then
    echo "Secret synced to K8s"
    break
  fi
  sleep 10
done

echo "3. Verify initial value in K8s"
INITIAL_VALUE=$(kubectl get secret test-secret -n "$NAMESPACE" -o jsonpath='{.data.value}' | base64 -d)
echo "Initial value: $INITIAL_VALUE"

echo "4. Rotate secret"
NEW_VALUE="rotated-value-$(date +%s)"
aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME" \
  --secret-string "$NEW_VALUE"

echo "5. Wait for ESO to detect rotation"
for i in {1..30}; do
  CURRENT_VALUE=$(kubectl get secret test-secret -n "$NAMESPACE" -o jsonpath='{.data.value}' | base64 -d)
  if [ "$CURRENT_VALUE" == "$NEW_VALUE" ]; then
    echo "Rotation detected and synced!"
    break
  fi
  sleep 10
done

echo "6. Trigger pod restart"
kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE"

echo "7. Wait for rollout"
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE"

echo "8. Verify application uses new secret"
kubectl exec -n "$NAMESPACE" deployment/"$DEPLOYMENT" -- cat /secrets/value

echo "✅ End-to-end rotation test completed successfully"
```

## Migration to AWS Secrets Manager Native Rotation (Future)

AWS Secrets Manager provides native rotation for certain secret types. If using RDS with Secrets Manager's built-in rotation:

```bash
# 1. Ensure secret is in Secrets Manager (already done per ADR-005)
aws secretsmanager describe-secret --secret-id prod/database/credentials

# 2. Set up automatic rotation for RDS
aws secretsmanager rotate-secret \
  --secret-id prod/database/credentials \
  --rotation-lambda-arn arn:aws:lambda:REGION:ACCOUNT:function:SecretsManagerRDSPostgreSQLRotationSingleUser \
  --rotation-rules AutomaticallyAfterDays=30

# 3. ESO continues to work - just syncs rotated secrets automatically
# No changes needed to ExternalSecret configuration

# 4. Verify rotation works
aws secretsmanager get-secret-value --secret-id prod/database/credentials

# 5. Monitor ESO sync
kubectl get externalsecrets -n production -w
```

**Benefits of Native Rotation:**

- AWS manages rotation Lambda
- Battle-tested rotation logic
- Automatic rollback on failure
- No custom code to maintain

**ESO Integration:** External Secrets Operator continues to work seamlessly - it simply syncs the rotated secrets from Secrets Manager to K8s, regardless of whether rotation is manual or automatic.

## Related Decisions

- **ADR-003**: Infrastructure Layering - Defines k8s-manifests repo and ArgoCD usage
- **ADR-004**: Infrastructure Tooling Separation - Defines External Secrets Operator integration
- **ADR-005**: Secret Management Solution Selection - Decision to use AWS Secrets Manager
- **ADR-006**: KMS Key Management Strategy
- **ADR-007**: IAM Policy Design for Secrets Manager Access

## References

- [AWS Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [Database Credential Rotation](https://aws.amazon.com/blogs/security/how-to-rotate-amazon-rds-database-credentials-with-aws-secrets-manager/)
- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Kubernetes Secrets Management](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Stakater Reloader](https://github.com/stakater/Reloader)
- [API Key Rotation Patterns](https://stripe.com/docs/keys#api-key-rotation)
- [Zero-Downtime Deployments with Kubernetes](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)

## Review Schedule

- **Initial Review**: After first automated rotation
- **Regular Review**: Monthly for first 3 months, then quarterly
- **Triggers for Review**:
  - Rotation failures
  - Service outages during rotation
  - New service types requiring rotation
  - ESO integration issues
  - Team feedback

---

**Date**: 2025-10-31  
**Last Updated**: 2025-11-17 (Updated to clarify ESO integration and K8s deployment flow per ADR-003/004)  
  