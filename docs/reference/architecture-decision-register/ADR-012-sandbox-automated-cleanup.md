# ADR-012: Automated Resource Cleanup for Sandbox Environment

## Status

Proposed

## Date

2024-11-24

## Context

The Sandbox environment (defined in [ADR-011](./ADR-011-sandbox-environment.md)) is designed for experimentation, testing, and learning. Without automated cleanup, resources accumulate over time, leading to:

1. **Escalating Costs**: Forgotten resources continue incurring charges indefinitely
2. **Resource Quota Exhaustion**: Old experiments consume service quotas, blocking new tests
3. **Cluttered Environment**: Difficult to identify active vs abandoned resources
4. **Security Risks**: Orphaned resources may have outdated security configurations
5. **Manual Overhead**: Team members spend time manually cleaning up old resources

### Current Situation

- Sandbox environment created with tagging strategy for cleanup (`AutoCleanup`, `MaxLifetime`, `ExpiresOn`)
- No automated cleanup mechanism implemented
- Manual cleanup via `terraform destroy` or AWS Console
- Resources documented to expire after specified periods, but enforcement is manual

### Requirements

1. **Automated Cleanup**: Remove resources automatically based on tags and age
2. **Safety**: Prevent accidental deletion of protected resources
3. **Visibility**: Team should know what will be cleaned up and when
4. **Override Capability**: Ability to protect specific resources from cleanup
5. **Audit Trail**: Complete logging of all cleanup operations
6. **Minimal Maintenance**: Solution should require minimal ongoing maintenance
7. **Cost Effective**: Cleanup solution shouldn't cost more than it saves

## Decision Drivers

- **Cost Control**: Primary driver to prevent runaway sandbox costs
- **Operational Efficiency**: Reduce manual cleanup burden
- **Safety**: Must not accidentally delete important resources
- **Simplicity**: Team should easily understand and maintain the solution
- **Terraform-Aware**: Should understand Terraform-managed resources
- **Multi-Service Support**: Works across all AWS services used in Sandbox

## Options Considered

### Option 1: AWS Nuke

#### Description - Option 1

[AWS Nuke](https://github.com/rebuy-de/aws-nuke) is an open-source tool that deletes all resources in an AWS account. Configured with filters to protect specific resources or delete only tagged resources.

#### Implementation Approach - Option 1

```yaml
# aws-nuke-config.yaml
regions:
  - us-east-1
  - us-west-2

account-blocklist:
  - "111111111111"  # Production
  - "222222222222"  # Staging
  - "333333333333"  # Development

accounts:
  "444444444444":  # Sandbox account ID
    filters:
      # Protect resources tagged with AutoCleanup=false
      EC2Instance:
        - type: tagged
          key: "AutoCleanup"
          value: "false"
      
      # Delete resources older than MaxLifetime
      EC2Instance:
        - type: tagged
          key: "AutoCleanup"
          value: "true"
        - type: older
          value: "7d"  # From MaxLifetime tag
```

**Deployment:**

- Run from Lambda on schedule (daily)
- Or run from GitHub Actions on schedule
- Or run manually as needed

#### Pros - Option 1

✅ **Comprehensive**: Supports 150+ AWS resource types out of the box

✅ **Battle-Tested**: Widely used in production environments, mature codebase

✅ **Powerful Filtering**: Complex filtering by tags, age, name patterns, resource types

✅ **Dry-Run Mode**: Test what would be deleted before actual deletion

✅ **Account Protection**: Built-in safeguards - requires account alias, must not contain 'prod', double confirmation

✅ **Open Source**: Free, community-supported, customizable

✅ **Complete Cleanup**: Can delete everything in account (useful for hard resets)

✅ **Active Development**: Version 3 (ekristen/aws-nuke) completely rewritten with libnuke library, 95+ test coverage

✅ **Global Filters**: v3 includes improved filtering, multi-region support, filter groups, name expansion

✅ **Multi-Region Ready**: Improved region handling, can run against all enabled regions

#### Cons - Option 1

❌ **Aggressive by Design**: Designed to nuke entire accounts, requires careful configuration

❌ **Not Terraform-Aware**: Doesn't understand Terraform state or dependencies (mitigated by filtering `ManagedBy=Terraform` tag)

❌ **Configuration Complexity**: YAML config can become complex with many filters

❌ **Resource Order Issues**: May attempt to delete resources in wrong order (improved in v3 with dependency handling)

❌ **Requires Container**: Runs as container/binary, needs hosting infrastructure

#### Implementation Effort - Option 1

**Initial Setup**: 8-12 hours

- Configure aws-nuke YAML file with filters
- Test in isolated account
- Set up Lambda or GitHub Actions runner
- Implement notification system
- Document runbook

**Ongoing Maintenance**: 2-4 hours/month

- Update filters as new resource types added
- Investigate cleanup failures
- Adjust configuration based on team feedback
- Update when aws-nuke releases new versions

**Risk**: Medium - Powerful tool requires careful configuration to avoid accidents

---

### Option 2: Cloud Nuke (by Gruntwork)

#### Description - Option 2

[Cloud Nuke](https://github.com/gruntwork-io/cloud-nuke) is an open-source tool by Gruntwork designed to delete cloud resources. More opinionated and safer than aws-nuke.

#### Implementation Approach - Option 2

```bash
# Command-line execution
cloud-nuke aws \
  --older-than 7d \
  --resource-type ec2,ebs,vpc,iam \
  --exclude-resource-tag AutoCleanup=false \
  --region us-east-1

# Config file approach
cloud-nuke aws --config config.yaml
```

```yaml
# config.yaml
regions:
  - us-east-1
  - us-west-2

resource-types:
  include:
    - ec2
    - ebs
    - vpc
    - iam
    - s3
    - rds

exclude:
  resource-tags:
    - key: AutoCleanup
      value: "false"
    - key: Protected
      value: "true"

older-than: 168h  # 7 days
```

**Deployment:**

- Lambda on EventBridge schedule
- GitHub Actions scheduled workflow
- Manual execution for emergency cleanup

#### Pros - Option 2

✅ **Terraform-Friendly**: Created by Gruntwork, understands Terraform patterns

✅ **Safer Defaults**: More conservative, less likely to cause accidents

✅ **Time-Based Filtering**: Built-in support for `--older-than` flag

✅ **Tag-Based Exclusions**: Simple tag-based protection

✅ **Multiple Resource Types**: Supports major AWS services (growing list)

✅ **Open Source**: Free, actively maintained by Gruntwork

✅ **Good Documentation**: Well-documented with examples

✅ **Dry-Run Mode**: `--dry-run` flag to preview deletions

#### Cons - Option 2

❌ **Limited Resource Coverage**: Supports ~30 resource types vs aws-nuke's 150+

❌ **Less Flexible Filtering**: Simpler filtering than aws-nuke

❌ **Slower Adoption of New Services**: May lag behind new AWS services

❌ **Basic Tag Logic**: Only supports exclusions, not complex tag-based rules

❌ **No ExpiresOn Support**: Doesn't natively check ExpiresOn tag, only time-based

❌ **Commercial Backing**: While open-source, heavily influenced by Gruntwork's priorities

#### Implementation Effort - Option 2

**Initial Setup**: 4-8 hours

- Create configuration file
- Test in isolated environment
- Deploy Lambda or GitHub Actions
- Set up notifications
- Document procedures

**Ongoing Maintenance**: 1-2 hours/month

- Adjust time thresholds
- Add new resource types as they become available
- Update exclusion tags
- Review and respond to cleanup failures

**Risk**: Low - Conservative by design, harder to make mistakes

---

### Option 3: Custom Lambda with AWS SDK

#### Description - Option 3

Build custom Lambda function that queries AWS resources by tags and deletes them based on custom logic.

#### Implementation Approach - Option 3

```python
# lambda_function.py
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    # Initialize clients
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')
    
    # Find and delete EC2 instances
    cleanup_ec2_instances(ec2)
    cleanup_rds_instances(rds)
    
    return {'statusCode': 200, 'body': 'Cleanup completed'}

def cleanup_ec2_instances(ec2):
    # Find instances tagged for cleanup
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:AutoCleanup', 'Values': ['true']},
            {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
        ]
    )
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            # Check MaxLifetime tag
            if should_cleanup(instance['Tags'], instance['LaunchTime']):
                instance_id = instance['InstanceId']
                print(f"Terminating instance: {instance_id}")
                ec2.terminate_instances(InstanceIds=[instance_id])

def should_cleanup(tags, launch_time):
    # Check AutoCleanup tag
    auto_cleanup = get_tag_value(tags, 'AutoCleanup')
    if auto_cleanup != 'true':
        return False
    
    # Check Protected tag
    protected = get_tag_value(tags, 'Protected')
    if protected == 'true':
        return False
    
    # Check ExpiresOn tag
    expires_on = get_tag_value(tags, 'ExpiresOn')
    if expires_on:
        expire_date = datetime.fromisoformat(expires_on)
        if datetime.now() >= expire_date:
            return True
    
    # Check MaxLifetime tag
    max_lifetime = get_tag_value(tags, 'MaxLifetime')
    if max_lifetime:
        days = parse_lifetime(max_lifetime)  # e.g., "7days" -> 7
        cutoff = datetime.now() - timedelta(days=days)
        if launch_time < cutoff:
            return True
    
    return False
```

**Infrastructure:**

```hcl
# terraform/env-sandbox/sandbox-layer/cleanup-automation/
resource "aws_lambda_function" "cleanup" {
  function_name = "sandbox-resource-cleanup"
  role          = aws_iam_role.cleanup_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300
  
  environment {
    variables = {
      DRY_RUN = "false"
      SNS_TOPIC_ARN = aws_sns_topic.cleanup_notifications.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_cleanup" {
  name                = "sandbox-daily-cleanup"
  description         = "Trigger cleanup Lambda daily"
  schedule_expression = "cron(0 2 * * ? *)"  # 2 AM UTC daily
}
```

#### Pros - Option 3

✅ **Complete Control**: Custom logic for any cleanup scenario

✅ **Terraform-Managed**: Cleanup infrastructure managed as code

✅ **Complex Tag Logic**: Can implement sophisticated tag-based rules

✅ **ExpiresOn Support**: Native support for ExpiresOn tag checking

✅ **Resource-Aware**: Can implement resource-specific cleanup logic

✅ **Integrated Notifications**: Direct SNS/email integration

✅ **Cost Efficient**: Only pay for Lambda execution (pennies/month)

✅ **No External Dependencies**: Pure AWS solution

✅ **Audit Integration**: Easy to integrate with CloudWatch Logs and CloudTrail

#### Cons - Option 3

❌ **Development Time**: Significant initial development effort

❌ **Maintenance Burden**: Team owns all code, bugs, and updates

❌ **Limited Coverage**: Must implement each resource type manually

❌ **Testing Complexity**: Need comprehensive tests to avoid bugs

❌ **Dependency Management**: Must handle order of resource deletion

❌ **Error Handling**: Complex error scenarios require careful coding

❌ **Scaling**: Performance issues if scanning thousands of resources

❌ **AWS API Changes**: Must update when AWS APIs change

#### Implementation Effort - Option 3

**Initial Setup**: 20-40 hours

- Design and implement Lambda function
- Support major resource types (EC2, RDS, S3, VPC, etc.)
- Implement tag parsing logic
- Build error handling and retry logic
- Create comprehensive test suite
- Set up notifications and monitoring
- Write Terraform code for infrastructure
- Document maintenance procedures

**Ongoing Maintenance**: 4-8 hours/month

- Add support for new resource types
- Fix bugs and edge cases
- Update for AWS API changes
- Respond to false positives/negatives
- Optimize performance
- Handle special cleanup scenarios

**Risk**: High - Custom code has bugs, team owns all issues

---

### Option 4: Terraform with Scheduled Destroys

#### Description - Option 4

Use Terraform Cloud or GitHub Actions to schedule `terraform destroy` operations for experiments.

#### Implementation Approach - Option 4

```yaml
# .github/workflows/cleanup-sandbox-experiments.yaml
name: Cleanup Expired Sandbox Experiments

on:
  schedule:
    - cron: '0 3 * * *'  # Daily at 3 AM UTC
  workflow_dispatch:  # Manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        experiment:
          - experiment-1
          - experiment-2
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Check if experiment expired
        id: check_expiry
        run: |
          EXPIRES_ON=$(grep ExpiresOn terraform/env-sandbox/sandbox-layer/experiments/${{ matrix.experiment }}/main.tf | cut -d'"' -f2)
          TODAY=$(date -u +%Y-%m-%d)
          if [[ "$TODAY" > "$EXPIRES_ON" ]]; then
            echo "expired=true" >> $GITHUB_OUTPUT
          fi
      
      - name: Configure AWS credentials
        if: steps.check_expiry.outputs.expired == 'true'
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::SANDBOX_ID:role/terraform-sandbox-experiments-human-role
          aws-region: us-east-1
      
      - name: Terraform Init
        if: steps.check_expiry.outputs.expired == 'true'
        working-directory: terraform/env-sandbox/sandbox-layer/experiments/${{ matrix.experiment }}
        run: terraform init
      
      - name: Terraform Destroy
        if: steps.check_expiry.outputs.expired == 'true'
        working-directory: terraform/env-sandbox/sandbox-layer/experiments/${{ matrix.experiment }}
        run: terraform destroy -auto-approve
```

**Terraform Cloud Approach:**

- Create workspace per experiment with expiration date
- Use Terraform Cloud API to trigger destroy
- Schedule via GitHub Actions or external scheduler

#### Pros - Option 4

✅ **Terraform-Native**: Uses Terraform's built-in destroy capability

✅ **State-Aware**: Understands Terraform state and dependencies

✅ **Proper Ordering**: Terraform handles resource deletion order

✅ **Safe**: Only destroys what Terraform created

✅ **No New Tools**: Uses existing Terraform infrastructure

✅ **Granular Control**: Per-workspace/experiment cleanup

✅ **Audit Trail**: Git history and Terraform Cloud logs

✅ **Rollback Possible**: Can restore from Terraform state backups

#### Cons - Option 4

❌ **Experiment-Specific**: Only works for Terraform-managed experiments

❌ **Manual Workflow Updates**: Must add each experiment to cleanup workflow

❌ **Doesn't Handle Orphans**: Won't cleanup resources created outside Terraform

❌ **State Drift Issues**: Fails if state doesn't match reality

❌ **Limited to Sandbox Layer**: Doesn't help with platform/application layers

❌ **No Time-Based Logic**: Must parse ExpiresOn from files (fragile)

❌ **Workflow Complexity**: Matrix builds become unwieldy with many experiments

❌ **Manual Resource Cleanup**: Resources created via Console need manual cleanup

#### Implementation Effort - Option 4

**Initial Setup**: 6-10 hours

- Create GitHub Actions workflow
- Set up OIDC authentication
- Implement expiration checking logic
- Configure notifications
- Test with sample experiments
- Document process for adding experiments

**Ongoing Maintenance**: 3-5 hours/month

- Add new experiments to workflow matrix
- Handle destroy failures
- Clean up workflows for completed experiments
- Manage Terraform state issues
- Update workflow as patterns evolve

**Risk**: Medium - Depends on Terraform state accuracy, manual workflow updates

---

### Option 5: Hybrid Approach (Cloud Nuke + Custom Logic)

#### Description - Option 5

Combine Cloud Nuke for general cleanup with custom Lambda for tag-based logic and Terraform awareness.

#### Implementation Approach - Option 5

**Phase 1 - Lightweight Custom Lambda:**

```python
# Check ExpiresOn tags and trigger cleanup
def lambda_handler(event, context):
    resources_to_cleanup = []
    
    # Find resources with expired ExpiresOn tags
    for resource in find_tagged_resources():
        if is_expired(resource):
            resources_to_cleanup.append(resource)
            tag_resource_for_nuke(resource)
    
    # Invoke Cloud Nuke for actual cleanup
    invoke_cloud_nuke(resources_to_cleanup)
```

**Phase 2 - Cloud Nuke Execution:**

```bash
# Cloud Nuke deletes resources tagged by Lambda
cloud-nuke aws \
  --exclude-resource-tag AutoCleanup=false \
  --exclude-resource-tag Protected=true \
  --include-resource-tag ReadyForCleanup=true
```

**Orchestration:**

1. Daily Lambda checks ExpiresOn and MaxLifetime tags
2. Lambda tags expired resources with `ReadyForCleanup=true`
3. Lambda invokes Cloud Nuke (via Step Functions or direct invoke)
4. Cloud Nuke deletes tagged resources
5. SNS notifications sent for all cleanup actions

#### Pros - Option 5

✅ **Best of Both**: Custom logic for tags + Cloud Nuke's deletion capability

✅ **ExpiresOn Support**: Lambda handles date-based cleanup

✅ **Broad Coverage**: Cloud Nuke handles many resource types

✅ **Safer**: Two-phase approach reduces accidental deletions

✅ **Terraform-Friendly**: Can integrate Terraform destroy for experiments

✅ **Flexible**: Can extend either component independently

✅ **Audit Trail**: Lambda logs decisions, Cloud Nuke logs deletions

#### Cons - Option 5

❌ **Increased Complexity**: Two systems to maintain and debug

❌ **Potential Failures**: More moving parts, more failure points

❌ **Coordination Required**: Lambda and Cloud Nuke must stay in sync

❌ **Higher Maintenance**: Both components need updates and care

❌ **Testing Complexity**: Must test integration between components

❌ **Cost**: Lambda + container hosting for Cloud Nuke

#### Implementation Effort - Option 5

**Initial Setup**: 16-24 hours

- Develop lightweight Lambda for tag checking
- Configure Cloud Nuke
- Build Step Functions orchestration
- Test integration thoroughly
- Set up monitoring and alerts
- Document both systems

**Ongoing Maintenance**: 3-6 hours/month

- Maintain Lambda code
- Update Cloud Nuke configuration
- Fix integration issues
- Adjust tag logic
- Respond to failures in either component

**Risk**: Medium-High - More complexity increases failure scenarios

---

## Comparison Matrix

| Criterion | AWS Nuke | Cloud Nuke | Custom Lambda | Terraform Destroy | Hybrid |
|-----------|----------|------------|---------------|-------------------|--------|
| **Initial Setup Time** | 8-12 hrs | 4-8 hrs | 20-40 hrs | 6-10 hrs | 16-24 hrs |
| **Ongoing Maintenance** | 2-4 hrs/mo | 1-2 hrs/mo | 4-8 hrs/mo | 3-5 hrs/mo | 3-6 hrs/mo |
| **Resource Coverage** | 150+ types | ~30 types | Custom | Terraform-only | 30+ types |
| **Tag Logic Complexity** | Basic | Basic | Advanced | Limited | Advanced |
| **Terraform-Aware** | No | Yes | Possible | Yes | Yes |
| **ExpiresOn Support** | No | No | Yes | Manual | Yes |
| **Safety Level** | Medium | High | Variable | High | High |
| **Cost** | Low | Low | Very Low | Very Low | Low |
| **Team Expertise Needed** | Low | Low | High | Medium | Medium-High |
| **Risk of Accidents** | Medium | Low | Medium | Low | Low |
| **Handles Orphans** | Yes | Yes | Yes | No | Yes |
| **Testing Complexity** | Medium | Low | High | Low | High |
| **Open Source** | Yes | Yes | N/A | N/A | Partial |

## Decision

### Recommended: Hybrid Approach - Terraform Destroy (for Terraform-managed) + AWS Nuke (for all other resources)

Two-tier cleanup strategy:

1. **Tier 1 - Terraform Destroy**: Scheduled destroy for Terraform-managed resources (tagged `ManagedBy=Terraform`)
2. **Tier 2 - AWS Nuke**: Aggressive cleanup for all other resources (manual experiments, Console-created, orphaned)

## Rationale

### Hybrid Two-Tier Approach: Terraform Destroy + AWS Nuke

The hybrid approach provides the best balance of safety, coverage, and Terraform awareness:

#### Tier 1: Terraform Destroy for Terraform-Managed Resources

**Why Terraform Destroy First:**

1. **State-Aware**: Understands dependencies and deletion order perfectly
2. **Safe**: Only destroys what Terraform created, won't touch manual resources
3. **Proper Cleanup**: Handles resources in correct dependency order
4. **Rollback Possible**: Can restore from Terraform state backups if needed
5. **Audit Trail**: Git history and Terraform Cloud logs provide complete record
6. **Team Familiarity**: Team already knows `terraform destroy` workflow

**Implementation**: Scheduled GitHub Actions workflow checks `ExpiresOn` tag in Terraform code and runs `terraform destroy` on expired workspaces.

#### Tier 2: AWS Nuke for Everything Else

**Why AWS Nuke (v3 - ekristen/aws-nuke):**

1. **Comprehensive Coverage**: 150+ resource types vs Cloud Nuke's ~30 types
2. **Version 3 Improvements**: Complete rewrite with libnuke library, 95%+ test coverage
3. **Better Safety**: Requires account alias, blocks 'prod' string, double confirmation
4. **Global Filters**: Advanced filtering capabilities, filter groups, name expansion
5. **Multi-Region Support**: Can run against all enabled regions simultaneously
6. **Active Development**: Actively maintained by ekristen with modern architecture
7. **Catches Everything**: Handles Console-created resources, orphaned resources, manual experiments

**Why AWS Nuke Over Cloud Nuke:**

- **More Resource Types**: 150+ vs 30 means better coverage for diverse experiments
- **Better for Testing**: Improved multi-region handling aligns with testing Terraform across regions
- **Safety Features**: Hard-coded 'prod' blocking and alias requirements provide additional safeguards
- **Modern Codebase**: v3 rewrite with dedicated library makes it more maintainable
- **Filter Flexibility**: Global filters and filter groups provide sophisticated control

**Cloud Nuke Advantages (Not Critical for Our Use Case)**:

- Can be imported as Go library (we don't need programmatic access)
- Commercial support from Gruntwork (not needed for Sandbox)
- `cloud-nuke-after` tag (we use `ExpiresOn` in Terraform)

### How the Hybrid Approach Works

```text
┌─────────────────────────────────────────────────────────────┐
│ Daily Cleanup Schedule (2 AM UTC)                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Terraform Destroy Workflow                          │
│                                                              │
│ 1. Find workspaces with expired ExpiresOn in Terraform code │
│ 2. Run terraform destroy for each expired workspace         │
│ 3. Clean removal of Terraform-managed infrastructure        │
│                                                              │
│ Tags: ManagedBy=Terraform                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Tier 2: AWS Nuke Cleanup                                     │
│                                                              │
│ 1. Scan all AWS resources in Sandbox account               │
│ 2. Exclude resources tagged ManagedBy=Terraform            │
│ 3. Exclude resources tagged Protected=true                  │
│ 4. Delete remaining resources older than 7 days            │
│                                                              │
│ Catches: Console resources, orphans, manual experiments     │
└─────────────────────────────────────────────────────────────┘
```

### Benefits of This Approach

✅ **Best of Both Worlds**: Terraform's state awareness + AWS Nuke's comprehensive coverage

✅ **Safety**: Terraform handles dependencies, AWS Nuke only touches non-Terraform resources

✅ **Complete Coverage**: Nothing escapes cleanup (Terraform-managed or manual)

✅ **Clear Separation**: `ManagedBy=Terraform` tag prevents AWS Nuke from touching Terraform resources

✅ **Team Alignment**: Terraform destroy for infrastructure-as-code, AWS Nuke for ad-hoc experiments

✅ **Flexibility**: Team can experiment in Console knowing AWS Nuke will clean up

✅ **Cost Effective**: Comprehensive cleanup prevents cost accumulation from any source

### Why Not Single-Tool Approaches?

**Terraform Destroy Only**: Misses Console-created resources, manual experiments, orphaned resources. Sandbox's purpose includes ad-hoc testing outside Terraform.

**AWS Nuke Only**: Could delete Terraform resources in wrong order, causing dependency errors. Better to let Terraform handle its own cleanup.

**Cloud Nuke Only**: Limited to ~30 resource types, may miss niche AWS services used in experiments. Less suitable for comprehensive testing environment.

**Custom Lambda Only**: 20-40 hours development time vs proven tools. Recreating functionality that exists in battle-tested open source.

## Implementation Plan

### Phase 1: Terraform Destroy Workflow (Week 1)

#### Day 1-2: GitHub Actions Workflow for Terraform Cleanup

```yaml
# .github/workflows/sandbox-terraform-cleanup.yaml
name: Sandbox Terraform Cleanup

on:
  schedule:
    - cron: '0 1 * * *'  # 1 AM UTC daily (before AWS Nuke)
  workflow_dispatch:

jobs:
  find-expired-workspaces:
    runs-on: ubuntu-latest
    outputs:
      workspaces: ${{ steps.find.outputs.workspaces }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Find expired Terraform workspaces
        id: find
        run: |
          # Find all terraform.tfvars or variables with ExpiresOn
          EXPIRED_WORKSPACES=$(find terraform/env-sandbox -name "*.tf" -o -name "*.tfvars" | \
            xargs grep -l "ExpiresOn" | \
            while read file; do
              EXPIRES=$(grep -oP 'ExpiresOn.*"\K[^"]+' "$file" || echo "")
              if [[ -n "$EXPIRES" ]] && [[ "$EXPIRES" < "$(date -u +%Y-%m-%d)" ]]; then
                dirname "$file"
              fi
            done | sort -u | jq -R -s -c 'split("\n")[:-1]')
          echo "workspaces=$EXPIRED_WORKSPACES" >> $GITHUB_OUTPUT
  
  destroy-expired:
    needs: find-expired-workspaces
    if: needs.find-expired-workspaces.outputs.workspaces != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        workspace: ${{ fromJson(needs.find-expired-workspaces.outputs.workspaces) }}
      fail-fast: false
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.SANDBOX_ACCOUNT_ID }}:role/terraform-sandbox-experiments-human-role
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init
        working-directory: ${{ matrix.workspace }}
        run: terraform init
      
      - name: Terraform Destroy
        working-directory: ${{ matrix.workspace }}
        run: terraform destroy -auto-approve
        
      - name: Notify cleanup
        if: always()
        uses: dawidd6/action-send-mail@v3
        with:
          server_address: smtp.gmail.com
          server_port: 465
          username: ${{ secrets.SMTP_USERNAME }}
          password: ${{ secrets.SMTP_PASSWORD }}
          subject: "Sandbox Terraform Cleanup: ${{ matrix.workspace }}"
          body: |
            Terraform workspace cleaned up: ${{ matrix.workspace }}
            Status: ${{ job.status }}
            Workflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          to: team@example.com
```

#### Day 3-4: Terraform Code Standards

**Require ExpiresOn in Sandbox Experiments:**

```hcl
# terraform/env-sandbox/sandbox-layer/experiments/example/variables.tf
variable "expires_on" {
  description = "Date when resources should be deleted (YYYY-MM-DD)"
  type        = string
  
  validation {
    condition     = can(formatdate("%Y-%m-%d", var.expires_on))
    error_message = "ExpiresOn must be a valid date in YYYY-MM-DD format."
  }
}

variable "owner" {
  description = "Owner of these resources"
  type        = string
}

# terraform/env-sandbox/sandbox-layer/experiments/example/main.tf
locals {
  common_tags = {
    Environment = "Sandbox"
    ManagedBy   = "Terraform"
    ExpiresOn   = var.expires_on
    Owner       = var.owner
    Layer       = "experiments"
  }
}

resource "aws_instance" "example" {
  # ... configuration ...
  
  tags = merge(local.common_tags, {
    Name = "sandbox-experiment-${var.owner}"
  })
}
```

#### Day 5: Testing

```bash
# Test workflow with short-lived resource
cd terraform/env-sandbox/sandbox-layer/experiments/test-cleanup/

# Create test resource expiring tomorrow
terraform apply -var="expires_on=$(date -d '+1 day' +%Y-%m-%d)" -var="owner=test"

# Manually trigger workflow to verify it finds expired resources
gh workflow run sandbox-terraform-cleanup.yaml

# Verify cleanup works correctly
```

### Phase 2: AWS Nuke Setup (Week 2)

#### Day 1-2: AWS Nuke v3 Configuration

```yaml
# aws-nuke-config.yaml (ekristen/aws-nuke v3)
regions:
  - us-east-1
  - us-west-2
  - global  # For IAM, Route53, etc.

account-blocklist:
  - "111111111111"  # Production account
  - "222222222222"  # Staging account
  - "333333333333"  # Development account
  - "444444444444"  # Management account

accounts:
  "555555555555":  # Sandbox account ID
    # Account alias required by AWS Nuke for safety
    # Must NOT contain 'prod' (hard-coded check)
    alias: sandbox-testing
    
    # Global filters apply to all resource types
    filters:
      # Exclude Terraform-managed resources (let Terraform destroy handle them)
      __global__:
        - type: "tag"
          key: "ManagedBy"
          value: "Terraform"
        - type: "tag"
          key: "Protected"
          value: "true"
        - type: "tag"
          key: "AutoCleanup"
          value: "false"
      
      # Protect foundation layer resources
      IAMRole:
        - property: "Name"
          type: "glob"
          value: "terraform-sandbox-*"
        - property: "Name"
          type: "glob"
          value: "*OIDC*"
      
      # Protect S3 buckets with state or logs
      S3Bucket:
        - property: "Name"
          type: "contains"
          value: "terraform-state"
        - property: "Name"
          type: "contains"
          value: "cloudtrail"
        - property: "Name"
          type: "contains"
          value: "logs"
      
      # Only delete resources older than 7 days
      EC2Instance:
        - property: "LaunchTime"
          type: "dateOlderThan"
          value: "7d"
      
      EC2Volume:
        - property: "CreateTime"
          type: "dateOlderThan"
          value: "7d"
      
      RDSInstance:
        - property: "InstanceCreateTime"
          type: "dateOlderThan"
          value: "7d"

# Feature flags for v3
feature-flags:
  disable-deletion-protection: false  # Don't force delete protected resources
  force-sleep: true  # Add delays between deletions
```

#### Day 3-4: Deployment Infrastructure

```hcl
# terraform/env-sandbox/sandbox-layer/cleanup-automation/main.tf

# ECR repository for AWS Nuke container image
resource "aws_ecr_repository" "aws_nuke" {
  name                 = "aws-nuke"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lambda to run AWS Nuke
resource "aws_lambda_function" "aws_nuke" {
  function_name = "sandbox-aws-nuke"
  role          = aws_iam_role.aws_nuke.arn
  
  # AWS Nuke v3 container
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.aws_nuke.repository_url}:latest"
  
  timeout       = 900  # 15 minutes
  memory_size   = 1024  # AWS Nuke needs more memory for large accounts
  
  environment {
    variables = {
      CONFIG_FILE = "/var/task/aws-nuke-config.yaml"
      DRY_RUN     = "false"  # Set to true initially for testing
    }
  }
}

# Daily schedule - runs AFTER Terraform cleanup (2 AM)
resource "aws_cloudwatch_event_rule" "daily_cleanup" {
  name                = "sandbox-daily-cleanup"
  description         = "Run AWS Nuke daily after Terraform cleanup"
  schedule_expression = "cron(0 2 * * ? *)"  # 2 AM UTC (1 hour after Terraform)
}

resource "aws_cloudwatch_event_target" "aws_nuke" {
  rule      = aws_cloudwatch_event_rule.daily_cleanup.name
  target_id = "AWSNukeLambda"
  arn       = aws_lambda_function.aws_nuke.arn
}

# SNS for notifications
resource "aws_sns_topic" "cleanup_notifications" {
  name = "sandbox-cleanup-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cleanup_notifications.arn
  protocol  = "email"
  endpoint  = var.team_email
}

# Lambda to send cleanup summary
resource "aws_lambda_function" "cleanup_notifier" {
  function_name = "sandbox-cleanup-notifier"
  role          = aws_iam_role.cleanup_notifier.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.cleanup_notifications.arn
    }
  }
}
```

#### Day 5: Container Build and Testing

```bash
# Build and push AWS Nuke container
cd terraform/env-sandbox/sandbox-layer/cleanup-automation/

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM public.ecr.aws/lambda/provided:al2

# Install AWS Nuke v3 (ekristen/aws-nuke)
RUN yum install -y wget && \
    wget https://github.com/ekristen/aws-nuke/releases/download/v3.0.0/aws-nuke-v3.0.0-linux-amd64.tar.gz && \
    tar -xzf aws-nuke-v3.0.0-linux-amd64.tar.gz && \
    mv aws-nuke /usr/local/bin/ && \
    chmod +x /usr/local/bin/aws-nuke

COPY aws-nuke-config.yaml /var/task/aws-nuke-config.yaml
COPY bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap

CMD ["aws-nuke"]
EOF

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO
docker build -t aws-nuke .
docker tag aws-nuke:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# Test in dry-run mode first
aws lambda invoke \
  --function-name sandbox-aws-nuke \
  --payload '{"dry-run": true}' \
  response.json

# Review what would be deleted
cat response.json

# Verify exclusions are working (ManagedBy=Terraform should be excluded)

# Test with actual deletion on test resource
# Create test EC2 instance WITHOUT ManagedBy=Terraform tag
aws ec2 run-instances \
  --image-id ami-12345 \
  --instance-type t2.micro \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=TestCleanup,Value=true}]'

# Wait 8 days (or modify config for testing)
# Run AWS Nuke to verify it deletes the test instance

# Deploy Lambda and test scheduled execution
terraform apply
```

#### Week 2: Documentation and Monitoring

##### Day 1-2: Documentation

- Update Sandbox README with cleanup procedures
- Create runbook for cleanup failures
- Document how to protect resources
- Create FAQ for common scenarios

##### Day 3-4: Monitoring and Alerts

```hcl
# CloudWatch alarms for both cleanup tiers
resource "aws_cloudwatch_metric_alarm" "terraform_cleanup_failures" {
  alarm_name          = "sandbox-terraform-cleanup-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedWorkflows"
  namespace           = "GitHubActions"
  period              = 86400  # Daily
  statistic           = "Sum"
  threshold           = 0
  
  alarm_actions = [aws_sns_topic.cleanup_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "aws_nuke_failures" {
  alarm_name          = "sandbox-aws-nuke-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 86400  # Daily
  statistic           = "Sum"
  threshold           = 0
  
  dimensions = {
    FunctionName = aws_lambda_function.aws_nuke.function_name
  }
  
  alarm_actions = [aws_sns_topic.cleanup_notifications.arn]
}

# Dashboard for cleanup metrics
resource "aws_cloudwatch_dashboard" "cleanup" {
  dashboard_name = "sandbox-cleanup"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", {stat = "Sum", label = "AWS Nuke Runs"}],
            [".", "Errors", {stat = "Sum", label = "AWS Nuke Errors"}],
            [".", "Duration", {stat = "Average", label = "AWS Nuke Duration"}]
          ]
          period = 86400
          stat   = "Sum"
          region = "us-east-1"
          title  = "AWS Nuke Cleanup Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query = "SOURCE '/aws/lambda/sandbox-aws-nuke' | fields @timestamp, @message | filter @message like /deleted/ | stats count() by bin(5m)"
          region = "us-east-1"
          title = "Resources Deleted by AWS Nuke"
        }
      }
    ]
  })
}
```

##### Day 5: Team Training

- Walkthrough with team on how cleanup works
- Demonstrate how to protect resources
- Show how to check what will be cleaned up
- Train on responding to cleanup issues

### Phase 3: Enhanced Notifications and Reporting (Future - Month 3-4)

Once both tiers are stable, add enhanced features:

**Pre-Cleanup Notifications:**

```python
# Lambda to notify before cleanup
def notify_expiring_resources(event, context):
    """
    Run 2 days before cleanup to notify owners of expiring Terraform workspaces
    """
    # Find Terraform workspaces expiring in 2 days
    expiring_soon = find_workspaces_expiring_within_days(2)
    
    for workspace in expiring_soon:
        owner = get_owner_from_tfvars(workspace)
        send_email(
            to=f"{owner}@company.com",
            subject=f"Sandbox Workspace Expiring Soon: {workspace}",
            body=f"""
            Your Terraform workspace will be destroyed in 2 days.
            
            Workspace: {workspace}
            Expires: {get_expiry_date(workspace)}
            
            To extend:
            1. Update ExpiresOn in your terraform.tfvars
            2. Commit and push to main branch
            
            To protect indefinitely:
            Add tag: AutoCleanup = "false"
            """
        )
```

**Cleanup Summary Reports:**

```python
def generate_cleanup_report(event, context):
    """
    Weekly summary of cleanup activities
    """
    # Gather data from CloudWatch Logs
    terraform_destroyed = count_terraform_destroys_last_week()
    aws_nuke_deleted = count_aws_nuke_deletions_last_week()
    cost_saved = estimate_cost_savings()
    
    send_email(
        to="team@company.com",
        subject="Sandbox Cleanup Weekly Summary",
        body=f"""
        Sandbox Cleanup Summary (Last 7 Days)
        
        Tier 1 - Terraform Destroy:
        - Workspaces destroyed: {terraform_destroyed}
        - Resources cleaned: {count_resources(terraform_destroyed)}
        
        Tier 2 - AWS Nuke:
        - Resources deleted: {aws_nuke_deleted}
        - Resource types: {list_resource_types(aws_nuke_deleted)}
        
        Estimated cost savings: ${cost_saved}/month
        
        Top resource creators: {top_owners()}
        """
    )
```

## Success Metrics

Track after 3 months of operation:

### Cost Metrics

- **Monthly Sandbox Spend Reduction**: Target 30-50% reduction
- **Orphaned Resource Cost**: Track cost of resources cleaned up
- **Cleanup Tool Cost**: Lambda + SNS costs (should be <$5/month)

### Operational Metrics

- **Resources Cleaned Per Week**: Track volume
- **Cleanup Failures**: Should be <5% of attempts
- **False Positives**: Resources incorrectly deleted (target: 0)
- **Manual Intervention Needed**: Should decrease over time

### Team Metrics

- **Time Spent on Manual Cleanup**: Should decrease to near-zero
- **Support Tickets for Cleanup**: Track questions/issues
- **Resources Protected**: Track Protected tag usage

## Rollback Plan

If Cloud Nuke causes issues:

1. **Immediate**: Disable CloudWatch Events rule to stop scheduled runs
2. **Short-term**: Switch to manual cleanup via Terraform destroy
3. **Investigation**: Review what went wrong, adjust configuration
4. **Resume**: Re-enable with more conservative settings

## Security and Safety

### Safety Measures

1. **Account Restrictions**: Cloud Nuke config only allows Sandbox account ID
2. **Dry-Run First**: Always test with `--dry-run` before actual cleanup
3. **Tag-Based Protection**: Multiple protection mechanisms (AutoCleanup=false, Protected=true)
4. **Notifications**: Team notified of all cleanup actions
5. **Audit Logs**: All deletions logged to CloudWatch and CloudTrail

### IAM Permissions

Lambda/AWS Nuke needs permissions to:

- Describe and delete resources across services (150+ resource types)
- Write to CloudWatch Logs
- Publish to SNS

```hcl
resource "aws_iam_role" "aws_nuke" {
  name = "AWSNukeExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Broad permissions needed for AWS Nuke to delete 150+ resource types
# Restricted to Sandbox account only
resource "aws_iam_role_policy" "aws_nuke" {
  name = "AWSNukePolicy"
  role = aws_iam_role.aws_nuke.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSNukeDeletePermissions"
        Effect = "Allow"
        Action = [
          # EC2 and related
          "ec2:Describe*",
          "ec2:Delete*",
          "ec2:Terminate*",
          "ec2:Release*",
          "ec2:Deregister*",
          
          # RDS
          "rds:Describe*",
          "rds:Delete*",
          
          # S3 (except protected buckets)
          "s3:ListBucket",
          "s3:DeleteBucket",
          "s3:DeleteObject*",
          
          # IAM (limited)
          "iam:List*",
          "iam:Get*",
          "iam:DeleteRole",
          "iam:DeleteUser",
          "iam:DeletePolicy",
          
          # Lambda
          "lambda:List*",
          "lambda:DeleteFunction",
          
          # EKS
          "eks:Describe*",
          "eks:DeleteCluster",
          
          # VPC and networking
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:Delete*",
          
          # CloudWatch
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          
          # SNS
          "sns:Publish"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": ["us-east-1", "us-west-2"]
          }
        }
      },
      {
        Sid = "PreventCriticalDeletion"
        Effect = "Deny"
        Action = [
          "iam:DeleteRole",
          "iam:DeletePolicy"
        ]
        Resource = [
          "arn:aws:iam::*:role/terraform-sandbox-*",
          "arn:aws:iam::*:role/*OIDC*"
        ]
      }
    ]
  })
}
```

**Note**: AWS Nuke requires broad permissions to delete 150+ resource types. This is acceptable in the Sandbox account because:

1. Account is isolated (not production)
2. Configuration file limits what gets deleted (filters)
3. Account alias check prevents running in wrong account
4. IAM deny policy protects critical roles
5. All deletions logged to CloudTrail

### Guardrails

1. **Region Restriction**: Only operate in specified regions
2. **Tag Requirements**: Resources must have proper tags to be in scope
3. **Age Threshold**: Don't delete very new resources (< 1 day old)
4. **Resource Type Allowlist**: Only delete specified resource types
5. **Confirmation Logs**: Log every deletion decision

## Consequences

### Positive

✅ **Reduced Costs**: Two-tier cleanup prevents cost accumulation from any source (estimated 40-60% reduction)

✅ **Complete Coverage**: Terraform-managed AND manual resources both cleaned up

✅ **Safe Terraform Cleanup**: State-aware destruction in proper dependency order

✅ **Comprehensive AWS Cleanup**: 150+ resource types covered by AWS Nuke

✅ **Clean Environment**: Sandbox stays tidy regardless of how resources were created

✅ **Team Efficiency**: No manual cleanup time needed for infrastructure OR experiments

✅ **Flexibility**: Team can experiment via Terraform or Console, both cleaned automatically

✅ **Resource Quotas**: Old resources don't consume quotas

✅ **Security**: Orphaned resources with stale configs removed

✅ **Battle-Tested Tools**: Both Terraform and AWS Nuke widely used and proven

✅ **Clear Separation**: `ManagedBy=Terraform` tag prevents tool overlap

### Negative

❌ **Two Systems**: Need to maintain both Terraform workflow and AWS Nuke configuration

❌ **Learning Curve**: Team needs to understand tagging requirements and when each tool applies

❌ **Coordination**: Terraform cleanup must run before AWS Nuke to avoid conflicts

❌ **External Dependency**: Relies on AWS Nuke (ekristen/aws-nuke) project maintenance

❌ **Broad IAM Permissions**: AWS Nuke requires wide permissions (mitigated by account isolation)

### Neutral

⚪ **Culture Change**: Team must adopt tagging discipline

⚪ **Monitoring Required**: Need to watch cleanup operations initially

⚪ **Iterative Improvement**: Will need adjustments based on usage patterns

## Alternatives Not Chosen

### Cloud Nuke Only

**Why Not**: Limited to ~30 AWS resource types vs AWS Nuke's 150+ types. Sandbox environment needs comprehensive coverage for diverse experiments. Missing resource types could lead to cost accumulation.

**When to Reconsider**: If AWS Nuke v3 proves unmaintainable or if commercial support from Gruntwork becomes necessary.

**Cloud Nuke Advantages We're Not Using**:

- Go library import (we don't need programmatic access)
- Commercial support from Gruntwork (not needed for Sandbox)
- `cloud-nuke-after` tag (we use `ExpiresOn` in Terraform code instead)

### Custom Lambda Only

**Why Not**: 20-40 hours initial development time. Recreating functionality that exists in proven open source tools (Terraform destroy + AWS Nuke). Team effort better spent on actual infrastructure work.

**When to Reconsider**: If both Terraform and AWS Nuke prove insufficient after 6+ months of real-world usage, and specific gaps are well-documented.

### AWS Nuke Only (Without Terraform Destroy)

**Why Not**: AWS Nuke doesn't understand Terraform state or resource dependencies. Deleting Terraform-managed resources via AWS Nuke could:

- Delete resources in wrong order (dependency errors)
- Leave Terraform state inconsistent with reality
- Cause issues when re-applying Terraform code

Better to let Terraform handle its own cleanup using `terraform destroy`.

**When to Reconsider**: Never. Terraform should always manage its own resource lifecycle.

### Terraform Destroy Only (Without AWS Nuke)

**Why Not**: Sandbox's purpose includes ad-hoc Console experimentation, manual testing, and learning. Terraform Destroy only handles Terraform-managed resources, missing:

- Console-created resources
- Manual experiments outside Terraform
- Orphaned resources from failed Terraform runs
- Resources created by other tools (SDKs, CLI, etc.)

**When to Reconsider**: If Sandbox usage becomes 100% Terraform-managed with no Console access (unlikely and defeats Sandbox purpose).

## Review and Updates

### Review Schedule

- **Week 2**: Initial assessment after deployment
- **Month 1**: First monthly review of metrics
- **Month 3**: Comprehensive review and Phase 2 decision
- **Month 6**: Evaluate if approach still optimal
- **Annually**: Major review of cleanup strategy

### Update Triggers

Re-evaluate this decision if:

- Cloud Nuke project becomes unmaintained
- Team size increases significantly (>15 engineers)
- Sandbox costs not reduced as expected (>20% after 3 months)
- False positive rate >5%
- New AWS services heavily used that aren't supported
- Compliance requirements change

## Related Decisions

- [ADR-011: Sandbox Environment](./ADR-011-sandbox-environment.md) - Defines Sandbox environment and tagging strategy
- [ADR-001: Terraform State Management](./ADR-001-terraform-state-management.md) - Terraform Cloud for state management
- [ADR-002: Terraform Workflow](./ADR-002-terraform-workflow-git-cicd.md) - CI/CD integration patterns

## References

- [AWS Nuke v3 (ekristen/aws-nuke)](https://github.com/ekristen/aws-nuke) - Recommended version
- [AWS Nuke v3 Documentation](https://ekristen.github.io/aws-nuke/)
- [libnuke Library](https://github.com/ekristen/libnuke) - Core library used by AWS Nuke v3
- [AWS Nuke v2 (rebuy-de/aws-nuke)](https://github.com/rebuy-de/aws-nuke) - Original version (less maintained)
- [Cloud Nuke GitHub](https://github.com/gruntwork-io/cloud-nuke) - Alternative tool
- [AWS Resource Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [Terraform Destroy Documentation](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [Gruntwork Blog on Cloud Nuke](https://blog.gruntwork.io/cloud-nuke-how-we-reduced-our-aws-bill-by-85-f3aced4e5876)

---

## Document Information

- **Created**: 2024-11-24
- **Author**: Platform Engineering Team
- **Reviewers**: [To be assigned]
- **Status**: Proposed
- **Version**: 1.0
- **Next Review**: 2025-02-24 (3 months after implementation)
