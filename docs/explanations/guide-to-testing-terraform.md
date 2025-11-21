# Comprehensive Guide to Testing Infrastructure-as-Code with Terraform

Testing infrastructure-as-code is critical to ensuring reliable, secure, and compliant infrastructure deployments. This guide provides detailed best practices and implementation strategies for testing Terraform in your environment, which uses Terraform Cloud, AWS Cloud across multiple accounts (Development, Staging, Production, and Sandbox), and maintains separate repositories for infrastructure code and Terraform modules.

## A.I. Source

Perplexity

### Prompt

Research the various best practices on testing infrastructure-as-code when using Terraform. Provide a comprehensive summary with detailed guidance on how to implement the recommended approaches. Assume we are using Terraform Cloud and are solely using AWS Cloud, with separate AWS accounts for Development, Staging, and Production environments. We also have another AWS account called Sandbox for the purpose of doing IaC testing. We have 2x code repositories for Terraform: One for the Terraform code for each environment and infrastructure layer (foundation, applications, platform); Another for our Terraform modules. Testing practices should consider local testing (on local environment), unit testing Terraform modules, integration testing of our stacks at each infrastructure layer, and smoke testing once we've applied Terraform in each environment. Be comprehensive.

## Testing Strategy Overview

A comprehensive Terraform testing strategy follows a layered approach, similar to the software testing pyramid. This ensures fast feedback loops, reduces costs, and maximizes test coverage:[1][2][3]

**Unit Testing** (Foundation): Fast, isolated tests of individual Terraform modules without creating real infrastructure. These tests validate logic, input validation, and expected resource configurations.[4][5]

**Integration Testing** (Middle Layer): Tests that verify modules work together correctly by deploying actual infrastructure in isolated environments. These validate end-to-end functionality and resource interactions.[5][6][4]

**End-to-End/Smoke Testing** (Top Layer): Comprehensive tests that validate complete infrastructure stacks in environments closely resembling production. These ensure business requirements are met and systems operate correctly.[7][8][5]

## Testing Environment Architecture

### Account Structure

Your AWS account structure naturally supports the testing pyramid:

**Sandbox Account**: Primary environment for running automated tests during development and CI/CD pipelines. This account is isolated from production and can be frequently reset.[9][4]

**Development Account**: Environment for deploying and validating infrastructure changes that have passed initial testing. Used for developer experimentation and feature validation.[10][11]

**Staging Account**: Pre-production environment that mirrors production configuration. Used for final integration testing and smoke testing before production deployment.[11][10]

**Production Account**: Live environment managed with the highest level of controls. Changes only deployed after passing all testing stages.[10][11]

### State File Isolation

State file isolation is critical for preventing cross-environment contamination. Implement the following strategies:[12][13][10]

**Separate State Files per Environment**: Use distinct backend configurations for each environment with separate S3 buckets and DynamoDB tables for state locking.[12][10]

**Workspace Naming Conventions**: If using Terraform Cloud workspaces, adopt clear naming patterns like `<layer>-<environment>` (e.g., `foundation-sandbox`, `applications-production`).[14][11]

**Backend Configuration per Environment**: Store backend configuration files separately and reference them during initialization:[15][10]

```hcl
# backend-sandbox.hcl
bucket         = "terraform-state-sandbox"
key            = "foundation/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks-sandbox"
encrypt        = true
```

## Local Testing Practices

Local testing provides the fastest feedback loop and should be performed before committing code.[16][17][18]

### Static Analysis and Validation

**Terraform Format**: Ensure consistent code formatting:[19][16]
```bash
terraform fmt -recursive
```

**Terraform Validate**: Check syntax and validate configuration correctness without accessing remote services:[20][16]
```bash
terraform validate
```

**TFLint**: Static analysis tool that identifies errors, potential issues, and enforces best practices:[18][21][22]
```bash
tflint --init
tflint --recursive
```

Configuration example (`.tflint.hcl`):
```hcl
plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "Owner", "CostCenter"]
}
```

### Pre-commit Hooks

Automate local testing with pre-commit hooks that run before code is committed:[23][21][24][22][18]

Install pre-commit framework:
```bash
pip install pre-commit
```

Configure `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.3
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=.tflint.hcl
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
      - --hook-config=--create-file-if-not-exist=true
```

Install the hooks:
```bash
pre-commit install
```

### Security and Compliance Scanning

**Checkov**: Static analysis tool that scans for security and compliance misconfigurations:[25][26][27][28]
```bash
checkov -d . --framework terraform
```

Run specific checks:
```bash
checkov -d . --check CKV_AWS_19,CKV_AWS_20 --compact
```

Common critical checks for AWS:
- `CKV_AWS_19`: Ensure S3 buckets have server-side encryption enabled
- `CKV_AWS_20`: Ensure S3 buckets are not publicly accessible
- `CKV_AWS_21`: Ensure S3 bucket has versioning enabled
- `CKV_AWS_40`: Ensure IAM policies are attached only to groups or roles

**tfsec**: Specialized security scanner for Terraform:[21][24]
```bash
tfsec . --format default
```

## Unit Testing Terraform Modules

Unit tests validate individual modules in isolation without creating real infrastructure.[29][30][4][5]

### Terraform Native Testing Framework

Terraform 1.6+ includes a native testing framework using `.tftest.hcl` files:[31][32][30][17][33]

**Basic Test Structure** (`tests/bucket_name.tftest.hcl`):
```hcl
# Test with plan command (no infrastructure created)
run "validate_bucket_name" {
  command = plan

  variables {
    bucket_name = "test-bucket-name"
    environment = "sandbox"
  }

  assert {
    condition     = aws_s3_bucket.main.bucket == "test-bucket-name"
    error_message = "Bucket name does not match expected value"
  }

  assert {
    condition     = aws_s3_bucket.main.tags["Environment"] == "sandbox"
    error_message = "Environment tag not set correctly"
  }
}
```

**Test with Mock Providers** (Terraform 1.7+):[34][35][36]
```hcl
# Mock AWS provider to avoid creating real resources
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::test-bucket-name"
      region = "us-east-1"
    }
  }
}

run "test_bucket_configuration" {
  command = plan

  variables {
    bucket_name = "test-bucket"
  }

  assert {
    condition     = aws_s3_bucket.main.bucket == "test-bucket"
    error_message = "Bucket name validation failed"
  }

  # Test computed attribute using mocked value
  assert {
    condition     = aws_s3_bucket.main.arn == "arn:aws:s3:::test-bucket-name"
    error_message = "Bucket ARN does not match expected value"
  }
}
```

**Running Tests**:
```bash
# Run all tests in current directory and tests/ directory
terraform test

# Run specific test file
terraform test -filter=tests/bucket_name.tftest.hcl

# Verbose output showing plan details
terraform test -verbose

# Run tests in Terraform Cloud (requires module published to private registry)
terraform test -cloud-run=app.terraform.io/your-org/your-module
```

### Advanced Testing with Terratest

Terratest is a Go library for writing automated tests that create real infrastructure:[37][38][39][40][41]

**Directory Structure**:
```
terraform-modules/
├── modules/
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── test/
    └── vpc_test.go
```

**Basic Terratest Example** (`test/vpc_test.go`):
```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "vpc_cidr": "10.0.0.0/16",
            "environment": "test",
        },
        EnvVars: map[string]string{
            "AWS_DEFAULT_REGION": "us-east-1",
        },
    }

    // Clean up resources after test
    defer terraform.Destroy(t, terraformOptions)

    // Run terraform init and apply
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)

    // Additional assertions
    vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr")
    assert.Equal(t, "10.0.0.0/16", vpcCidr)
}
```

**Running Terratest**:
```bash
cd test
go test -v -timeout 30m
```

**Best Practices for Terratest**:[38][40][37]
- Run tests in parallel when possible using `t.Parallel()`
- Set appropriate timeouts for long-running infrastructure
- Always use `defer terraform.Destroy()` to clean up resources
- Use retry and polling helpers for eventual consistency
- Tag resources with test identifiers for easier cleanup

### Module Testing in Terraform Cloud Private Registry

Terraform Cloud's private registry supports automated testing during module publishing:[42][43][4]

**Enable Test-Integrated Publishing**:
1. Navigate to your module in Terraform Cloud private registry
2. Enable "Branch-based publishing" workflow
3. Configure test settings to run `.tftest.hcl` files before publishing
4. Tests run automatically on pull requests and commits

**Benefits**:[4][42]
- Automated test execution before module release
- Test results visible in the UI
- Failed tests prevent module version publishing
- Integrates with VCS workflows

## Integration Testing

Integration tests verify that multiple Terraform modules and resources work correctly together after deployment.[6][5][29][4]

### Test Environment Setup

**Dedicated Sandbox Resources**: Create isolated test environments in your Sandbox AWS account:[29][4]

```hcl
# tests/integration/main.tf
module "vpc" {
  source = "../../modules/vpc"
  
  vpc_cidr    = "10.100.0.0/16"
  environment = "integration-test"
  
  tags = {
    TestRun = var.test_run_id
    Purpose = "automated-testing"
  }
}

module "application" {
  source = "../../modules/application"
  
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  environment = "integration-test"
}
```

### Integration Test Strategy

**Test File Structure** (`tests/integration.tftest.hcl`):
```hcl
variables {
  test_run_id = "integration-${timestamp()}"
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      TestRun = var.test_run_id
      ManagedBy = "terraform-test"
    }
  }
}

run "setup" {
  command = apply
  
  module {
    source = "./tests/integration"
  }
}

run "verify_vpc_integration" {
  command = plan
  
  assert {
    condition     = module.vpc.vpc_id != ""
    error_message = "VPC was not created successfully"
  }
  
  assert {
    condition     = length(module.vpc.private_subnet_ids) > 0
    error_message = "Private subnets were not created"
  }
}

run "verify_application_integration" {
  command = plan
  
  assert {
    condition     = module.application.load_balancer_dns != ""
    error_message = "Load balancer was not created"
  }
}

run "cleanup" {
  command = destroy
}
```

### Testing Resource Dependencies

Validate that resources are created in the correct order and with proper dependencies:[5][6]

```hcl
run "test_dependency_chain" {
  command = apply

  assert {
    condition = (
      aws_vpc.main.id != "" &&
      aws_subnet.private[0].vpc_id == aws_vpc.main.id &&
      aws_instance.app[0].subnet_id == aws_subnet.private[0].id
    )
    error_message = "Resource dependency chain is broken"
  }
}
```

### Cost Management for Integration Tests

Integration tests create real resources and incur costs. Implement these strategies:[44][4][29]

**Minimize Resource Sizes**:[4]
```hcl
variable "instance_type" {
  default = terraform.workspace == "test" ? "t3.micro" : "t3.large"
}
```

**Lifecycle Management**:[29][4]
- Run tests in dedicated Sandbox account to track testing costs separately
- Use tags to identify test resources: `Purpose = "automated-testing"`
- Implement automatic cleanup after test completion
- Schedule regular cleanup jobs to remove orphaned test resources

**AWS Nuke for Cleanup**:[9]
```yaml
# nuke-config.yml
regions:
  - us-east-1

account-blocklist:
  - "999999999999" # Production account ID

resource-types:
  targets:
    - EC2Instance
    - S3Bucket
    - RDSInstance
  
filters:
  EC2Instance:
    - property: tag:ManagedBy
      value: "terraform-test"
```

## Testing Infrastructure Layers

With your repository structure separating foundation, platform, and applications layers, implement layer-specific testing strategies:[12]

### Foundation Layer Testing

The foundation layer (VPCs, networking, IAM) changes infrequently and requires thorough testing:[12]

**Test Strategy**:
- Comprehensive unit tests for all modules
- Full integration tests in Sandbox before deployment
- Smoke tests after applying to each environment
- Avoid frequent changes to minimize risk

**Example Test** (`foundation/tests/vpc.tftest.hcl`):
```hcl
run "validate_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    environment = "sandbox"
  }

  assert {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Invalid CIDR block provided"
  }
}

run "validate_subnet_distribution" {
  command = plan

  assert {
    condition = length([
      for subnet in aws_subnet.private : subnet
      if can(regex("^10\\.0\\.[0-9]+\\.0/24$", subnet.cidr_block))
    ]) == length(aws_subnet.private)
    error_message = "Subnets not properly distributed"
  }
}
```

### Platform Layer Testing

Platform layer (Kubernetes, databases, middleware) requires both unit and integration testing:

**Test Strategy**:
- Unit tests for module configuration
- Integration tests with foundation layer dependencies
- Smoke tests validating service connectivity

### Applications Layer Testing

Application infrastructure changes most frequently and needs fast feedback:

**Test Strategy**:
- Extensive unit tests with mocking
- Selective integration tests for critical paths
- Automated smoke tests after every deployment

## Smoke Testing in Each Environment

Smoke tests validate critical functionality after infrastructure deployment:[45][8][46][47][7]

### Infrastructure Smoke Tests

**Server Availability**:[7]
```bash
#!/bin/bash
# smoke-tests/check-server.sh

SERVER_ADDRESS=$1
MAX_RETRIES=5
RETRY_DELAY=10

for i in $(seq 1 $MAX_RETRIES); do
  if nc -zv $SERVER_ADDRESS 22 2>&1 | grep -q "succeeded"; then
    echo "✓ Server is reachable"
    exit 0
  fi
  echo "Attempt $i failed, retrying in ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

echo "✗ Server unreachable after $MAX_RETRIES attempts"
exit 1
```

**Database Connectivity**:[7]
```bash
#!/bin/bash
# smoke-tests/check-database.sh

DB_HOST=$1
DB_PORT=$2
DB_NAME=$3

pg_isready -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME"
if [ $? -eq 0 ]; then
  echo "✓ Database is ready"
  exit 0
else
  echo "✗ Database connection failed"
  exit 1
fi
```

**Load Balancer Health**:[8][7]
```bash
#!/bin/bash
# smoke-tests/check-load-balancer.sh

LB_URL=$1
EXPECTED_STATUS=200
MAX_RETRIES=10
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$LB_URL/health")
  
  if [ "$STATUS" -eq "$EXPECTED_STATUS" ]; then
    echo "✓ Load balancer health check passed (HTTP $STATUS)"
    exit 0
  fi
  
  echo "Attempt $i: HTTP $STATUS (expected $EXPECTED_STATUS), retrying..."
  sleep $RETRY_DELAY
done

echo "✗ Load balancer health check failed after $MAX_RETRIES attempts"
exit 1
```

### Smoke Test Integration

**Terraform Outputs for Smoke Tests**:
```hcl
# outputs.tf
output "smoke_test_endpoints" {
  value = {
    load_balancer_url = aws_lb.main.dns_name
    database_endpoint = aws_db_instance.main.endpoint
    application_url   = "https://${aws_route53_record.app.fqdn}"
  }
  description = "Endpoints for smoke testing"
}
```

**Run Smoke Tests After Apply**:
```bash
#!/bin/bash
# run-smoke-tests.sh

# Get outputs from Terraform
LB_URL=$(terraform output -raw smoke_test_endpoints | jq -r '.load_balancer_url')
DB_ENDPOINT=$(terraform output -raw smoke_test_endpoints | jq -r '.database_endpoint')

# Run smoke tests
./smoke-tests/check-load-balancer.sh "$LB_URL"
./smoke-tests/check-database.sh "$DB_ENDPOINT"

# Exit with failure if any test failed
if [ $? -ne 0 ]; then
  echo "Smoke tests failed"
  exit 1
fi

echo "All smoke tests passed"
```

## Policy and Compliance Testing

Enforce organizational policies and compliance requirements before infrastructure deployment:[48][49][50][51][52]

### Open Policy Agent (OPA)

**Policy Structure** (`policies/require-encryption.rego`):
```rego
package terraform.encryption

import input.plan as tfplan

# Check S3 buckets have encryption
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.server_side_encryption_configuration
    
    msg := sprintf(
        "S3 bucket '%s' must have server-side encryption enabled",
        [resource.address]
    )
}

# Check EBS volumes are encrypted
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_ebs_volume"
    resource.change.after.encrypted != true
    
    msg := sprintf(
        "EBS volume '%s' must be encrypted",
        [resource.address]
    )
}

# Check RDS instances are encrypted
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.after.storage_encrypted != true
    
    msg := sprintf(
        "RDS instance '%s' must have storage encryption enabled",
        [resource.address]
    )
}
```

**Testing the Policy**:
```bash
# Generate Terraform plan in JSON format
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Evaluate policy
opa eval --input tfplan.json --data policies/ "data.terraform.encryption.deny"
```

**Policy Testing** (`policies/require-encryption_test.rego`):
```rego
package terraform.encryption

test_s3_bucket_without_encryption {
    deny["S3 bucket 'aws_s3_bucket.test' must have server-side encryption enabled"] with input as {
        "plan": {
            "resource_changes": [{
                "type": "aws_s3_bucket",
                "address": "aws_s3_bucket.test",
                "change": {"after": {}}
            }]
        }
    }
}

test_s3_bucket_with_encryption {
    not deny[_] with input as {
        "plan": {
            "resource_changes": [{
                "type": "aws_s3_bucket",
                "address": "aws_s3_bucket.test",
                "change": {
                    "after": {
                        "server_side_encryption_configuration": {}
                    }
                }
            }]
        }
    }
}
```

### Terraform Cloud Policy Enforcement

Terraform Cloud supports OPA policies through Policy Sets:[49][52]

1. Create policy set in Terraform Cloud
2. Upload `.rego` files and test files
3. Configure enforcement level (advisory, soft-mandatory, hard-mandatory)
4. Apply to specific workspaces or all workspaces

## CI/CD Pipeline Integration

Integrate testing into your CI/CD pipeline for automated validation:[53][54][55][56]

### GitHub Actions Workflow Example

**Complete Testing Workflow** (`.github/workflows/terraform-test.yml`):
```yaml
name: Terraform Testing Pipeline

on:
  pull_request:
    branches: [main, develop]
    paths:
      - '**.tf'
      - '**.tfvars'
  push:
    branches: [main]

env:
  TF_VERSION: '1.7.0'
  AWS_REGION: 'us-east-1'

jobs:
  static-analysis:
    name: Static Analysis
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        run: |
          terraform init -backend=false
          terraform validate

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: latest

      - name: Run TFLint
        run: |
          tflint --init
          tflint --recursive --format compact

      - name: Checkov Security Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          soft_fail: false
          output_format: cli,sarif
          output_file_path: console,checkov-results.sarif

      - name: Upload Checkov Results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: checkov-results.sarif

  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: static-analysis
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_SANDBOX }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Run Terraform Tests
        run: |
          cd modules
          terraform test -verbose

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: unit-tests
    if: github.event_name == 'pull_request'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_SANDBOX }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Go for Terratest
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run Integration Tests
        working-directory: test
        run: |
          go mod download
          go test -v -timeout 60m -parallel 4

      - name: Cleanup Test Resources
        if: always()
        run: |
          # Tag-based cleanup
          aws resourcegroupstaggingapi get-resources \
            --tag-filters Key=ManagedBy,Values=terraform-test \
            --query 'ResourceTagMappingList[*].ResourceARN' \
            --output text | \
          xargs -I {} aws resourcegroupstaggingapi untag-resources \
            --resource-arn-list {}

  policy-check:
    name: Policy Validation
    runs-on: ubuntu-latest
    needs: static-analysis
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_SANDBOX }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Generate Terraform Plan
        run: |
          terraform init
          terraform plan -out=tfplan.binary
          terraform show -json tfplan.binary > tfplan.json

      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2
        with:
          version: latest

      - name: Run OPA Policy Check
        run: |
          opa eval \
            --input tfplan.json \
            --data policies/ \
            --format pretty \
            "data.terraform.deny"

  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    needs: [unit-tests, policy-check]
    if: github.event_name == 'pull_request'
    
    strategy:
      matrix:
        environment: [sandbox, development]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}

      - name: Terraform Plan
        run: |
          terraform init \
            -backend-config="workspace=${{ matrix.environment }}"
          terraform plan \
            -var-file="environments/${{ matrix.environment }}.tfvars" \
            -out=tfplan-${{ matrix.environment }}

      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: tfplan-${{ matrix.environment }}

  terraform-apply-dev:
    name: Apply to Development
    runs-on: ubuntu-latest
    needs: [integration-tests, terraform-plan]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: development
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_DEVELOPMENT }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Apply
        run: |
          terraform init \
            -backend-config="workspace=development"
          terraform apply \
            -var-file="environments/development.tfvars" \
            -auto-approve

      - name: Run Smoke Tests
        run: |
          # Extract outputs
          LB_URL=$(terraform output -json smoke_test_endpoints | jq -r '.load_balancer_url')
          
          # Run smoke tests
          ./smoke-tests/check-load-balancer.sh "$LB_URL"
          
      - name: Notify on Failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployment to Development failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "❌ Terraform Apply to Development failed\n*Workflow:* ${{ github.workflow }}\n*Run:* <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Run>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Terraform Cloud Integration

For Terraform Cloud workflows:[57][58][59]

**Workspace Configuration**:
- Configure VCS integration for automatic runs
- Set up workspace variables for each environment
- Enable health assessments for drift detection
- Configure notification settings

**Run Triggers**:
```hcl
# In foundation workspace
resource "tfe_workspace" "platform" {
  name         = "platform-production"
  organization = var.tfe_organization
  
  trigger_prefixes = [
    "modules/vpc",
    "modules/networking"
  ]
}

resource "tfe_run_trigger" "foundation_to_platform" {
  workspace_id  = tfe_workspace.platform.id
  sourceable_id = tfe_workspace.foundation.id
}
```

## Drift Detection and Management

Detect and manage infrastructure drift to ensure infrastructure matches code:[60][61][62][63]

### Terraform Cloud Health Assessments

Enable continuous drift detection:[64]

1. Navigate to workspace settings
2. Enable "Health Assessments"
3. Configure assessment frequency (hourly, daily, weekly)
4. Set up notifications for drift detection

### Manual Drift Detection

**Scheduled Drift Checks**:
```bash
#!/bin/bash
# drift-detection.sh

ENVIRONMENTS=("development" "staging" "production")

for ENV in "${ENVIRONMENTS[@]}"; do
  echo "Checking drift in $ENV environment..."
  
  terraform init -backend-config="workspace=$ENV"
  terraform plan -detailed-exitcode -var-file="environments/$ENV.tfvars"
  
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 2 ]; then
    echo "⚠️  Drift detected in $ENV environment"
    # Send notification
    curl -X POST $SLACK_WEBHOOK_URL \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\"Infrastructure drift detected in $ENV environment\"}"
  elif [ $EXIT_CODE -eq 0 ]; then
    echo "✓ No drift in $ENV environment"
  else
    echo "✗ Error checking drift in $ENV environment"
  fi
done
```

**Drift Remediation Workflow**:
1. Detect drift via scheduled checks or health assessments
2. Review drift to determine if it's intentional or problematic
3. Update Terraform code to match infrastructure (if change is desired)
4. Apply Terraform to restore desired state (if drift is unintended)
5. Investigate root cause and implement preventive controls

## Module Versioning and Testing

Proper module versioning ensures stable, predictable infrastructure deployments:[65][66][67][68]

### Semantic Versioning

Follow semantic versioning for all modules:[66][68][65]

- **MAJOR** (1.x.x): Breaking changes that require updates to module consumers
- **MINOR** (x.1.x): New features added in backward-compatible manner
- **PATCH** (x.x.1): Backward-compatible bug fixes

**Version Constraints in Module Calls**:
```hcl
module "vpc" {
  source  = "app.terraform.io/your-org/vpc/aws"
  version = "~> 2.1" # Allow 2.1.x, but not 2.2.0
  
  vpc_cidr = "10.0.0.0/16"
}
```

### Module Testing Before Release

**Pre-release Testing Checklist**:
1. Run all unit tests with mocked providers
2. Execute integration tests in Sandbox account
3. Validate backward compatibility with existing consumers
4. Update module documentation
5. Tag release with appropriate semantic version

**Automated Release Workflow** (`.github/workflows/module-release.yml`):
```yaml
name: Module Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  test-and-release:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Validate Version Tag
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          if [[ ! $TAG =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid version tag format: $TAG"
            exit 1
          fi

      - name: Run All Tests
        run: |
          terraform test -verbose

      - name: Publish to Terraform Cloud Registry
        env:
          TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
        run: |
          # Terraform Cloud auto-publishes from Git tags
          echo "Module will be published to registry with tag ${GITHUB_REF#refs/tags/}"
```

## Best Practices Summary

### Development Workflow

1. **Write Infrastructure Code**: Develop Terraform configurations in feature branches
2. **Local Testing**: Run static analysis, validation, and unit tests locally
3. **Commit with Pre-commit Hooks**: Automated checks before code commit
4. **Create Pull Request**: Triggers CI/CD pipeline with comprehensive testing
5. **Code Review**: Review test results, security scans, and Terraform plans
6. **Merge to Main**: Triggers deployment to Development environment
7. **Promote Through Environments**: Deploy to Staging, then Production after validation

### Testing Best Practices

**Prioritize Fast Feedback**:[2][3][1]
- Majority of tests should be unit tests (fast, no infrastructure)
- Moderate number of integration tests (slower, real infrastructure)
- Minimal end-to-end tests (slowest, full stack validation)

**Isolate Test Environments**:[10][12]
- Use separate AWS accounts for testing
- Implement proper state file isolation
- Tag all test resources for easy identification

**Automate Everything**:[54][53]
- Integrate testing into CI/CD pipelines
- Use pre-commit hooks for local automation
- Schedule regular drift detection checks

**Manage Costs**:[44][4]
- Run expensive tests only when necessary
- Use smallest resource sizes for testing
- Implement automatic cleanup of test resources
- Monitor and track testing costs separately

**Version Control**:[65][66]
- Use semantic versioning for all modules
- Test modules thoroughly before releases
- Pin module versions in production configurations
- Document breaking changes clearly

**Security First**:[26][28][25]
- Run security scans on all infrastructure code
- Enforce compliance policies via OPA or Sentinel
- Never commit secrets or credentials
- Implement least-privilege IAM for testing

### Key Testing Metrics

Monitor these metrics to ensure testing effectiveness:

**Test Coverage**: Percentage of modules with automated tests
**Test Execution Time**: Time from commit to test completion
**Test Pass Rate**: Percentage of tests passing on first run
**Drift Frequency**: How often drift is detected
**Time to Remediate**: Time from drift detection to resolution
**Cost per Test Run**: AWS costs incurred during testing
**Mean Time to Recovery**: Time to restore after failed deployment

## Repository-Specific Recommendations

### Infrastructure Code Repository

**Directory Structure**:
```
terraform-infrastructure/
├── .github/
│   └── workflows/
│       ├── terraform-test.yml
│       └── terraform-deploy.yml
├── foundation/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── tests/
│       ├── vpc.tftest.hcl
│       └── iam.tftest.hcl
├── platform/
│   ├── main.tf
│   └── tests/
├── applications/
│   ├── main.tf
│   └── tests/
├── environments/
│   ├── sandbox.tfvars
│   ├── development.tfvars
│   ├── staging.tfvars
│   └── production.tfvars
├── smoke-tests/
│   ├── check-server.sh
│   ├── check-database.sh
│   └── check-load-balancer.sh
├── policies/
│   ├── require-encryption.rego
│   └── require-tags.rego
└── .pre-commit-config.yaml
```

### Modules Repository

**Directory Structure**:
```
terraform-modules/
├── .github/
│   └── workflows/
│       ├── module-test.yml
│       └── module-release.yml
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── README.md
│   │   └── tests/
│   │       ├── unit.tftest.hcl
│   │       └── integration.tftest.hcl
│   ├── eks-cluster/
│   │   └── ...
│   └── rds-instance/
│       └── ...
├── test/
│   ├── go.mod
│   ├── vpc_test.go
│   └── eks_test.go
├── examples/
│   ├── vpc-basic/
│   └── vpc-advanced/
└── .pre-commit-config.yaml
```

## Conclusion

Testing infrastructure-as-code with Terraform requires a comprehensive, multi-layered approach. By implementing unit testing for modules, integration testing for component interactions, smoke testing after deployments, and continuous drift detection, you create a robust testing framework that ensures reliable, secure, and compliant infrastructure.

The key to success is automation—integrate testing into every stage of your development workflow, from local pre-commit hooks to CI/CD pipelines to production monitoring. With proper testing in place, you gain confidence in infrastructure changes, reduce deployment failures, and maintain infrastructure that consistently matches your desired state.

Your environment with Terraform Cloud, separate AWS accounts, and dedicated repositories for infrastructure code and modules provides an excellent foundation for implementing these testing practices. Start with the basics—static analysis and unit testing—then progressively add integration testing, smoke testing, and policy enforcement as your testing maturity grows.[30][17][6][25][26][53][54][5][4][29]

[1](https://www.virtuosoqa.com/post/what-is-the-testing-pyramid)
[2](https://www.frugaltesting.com/blog/the-testing-pyramid-a-guide-to-effective-software-testing)
[3](https://semaphore.io/blog/testing-pyramid)
[4](https://www.hashicorp.com/en/blog/testing-hashicorp-terraform)
[5](https://www.linkedin.com/pulse/terraform-testing-demystified-building-reliable-infrastructure-k-6pcbc)
[6](https://docs.cloud.google.com/docs/terraform/best-practices/testing)
[7](https://semaphore.io/community/tutorials/smoke-testing)
[8](https://circleci.com/blog/smoke-tests-in-cicd-pipelines/)
[9](https://www.infoq.com/articles/aws-sandbox-as-a-service/)
[10](https://dev.to/patdevops/terraform-state-secrets-best-practices-for-isolating-multi-environment-setups-5080)
[11](https://scalr.com/glossary/terraform-workspaces)
[12](https://www.gruntwork.io/blog/how-to-manage-terraform-state)
[13](https://spacelift.io/blog/terraform-state)
[14](https://www.env0.com/blog/terraform-workspaces-guide-examples-commands-and-best-practices)
[15](https://aws.amazon.com/blogs/devops/best-practices-for-managing-terraform-state-files-in-aws-ci-cd-pipeline/)
[16](https://spacelift.io/blog/terraform-validate)
[17](https://spacelift.io/blog/terraform-test)
[18](https://blog.technocirrus.com/leveraging-pre-commit-hook-to-write-an-error-free-terraform-code-2eb13a9e77d8)
[19](https://www.linkedin.com/pulse/day-88100-cicd-terraform-lint-validate-plan-apply-via-chikkela-bz2me)
[20](https://developer.hashicorp.com/terraform/language/validate)
[21](https://seifrajhi.github.io/blog/pre-commit-hooks-terraform-code-quality/)
[22](https://github.com/antonbabenko/pre-commit-terraform)
[23](https://github.com/gruntwork-io/pre-commit)
[24](https://luke.geek.nz/misc/precommit-hooks-codespaces-terraform-iac)
[25](https://igorzhivilo.com/2025/02/11/checkov-ci/)
[26](https://scalr.com/blog/using-checkov-with-terraform-integrations-features-examples)
[27](https://itnext.io/review-testing-terraform-infrastructure-as-code-with-unit-tests-bdd-e2e-with-checkov-and-9b05ca7655d2)
[28](https://blogs.halodoc.io/securing-your-terraform-code-with-checkov-a-guide/)
[29](https://zeet.co/blog/terraform-testing-tools)
[30](https://aws.amazon.com/blogs/devops/terraform-ci-cd-and-testing-on-aws-with-the-new-terraform-test-framework/)
[31](https://scalr.com/blog/mastering-terraform-at-scale-a-developers-guide-to-robust-infrastructure)
[32](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
[33](https://mattias.engineer/blog/2023/terraform-testing-deep-dive/)
[34](https://developer.hashicorp.com/terraform/language/tests/mocking)
[35](https://www.hashicorp.com/en/blog/terraform-1-7-adds-test-mocking-and-config-driven-remove)
[36](https://mattias.engineer/blog/2024/terraform-test-mocks/)
[37](https://terrateam.io/blog/automated-testing-for-terraform-with-terratest)
[38](https://caylent.com/blog/testing-your-code-on-terraform-terratest)
[39](https://benmatselby.dev/post/terratest/)
[40](https://terratest.gruntwork.io/docs/getting-started/quick-start/)
[41](https://terratest.gruntwork.io)
[42](https://www.youtube.com/watch?v=J1z7A0y2LMw)
[43](https://www.youtube.com/watch?v=2Wo0a0xEVVA)
[44](https://controlmonkey.io/blog/terraform-aws-cost-optimization-playbook/)
[45](https://testgrid.io/blog/smoke-testing-everything-you-need-to-know/)
[46](https://www.getunleash.io/blog/rolling-deployment-vs-smoke-test)
[47](https://www.browserstack.com/guide/smoke-testing-automation)
[48](https://openpolicyagent.org/docs/terraform)
[49](https://scalr.com/blog/everything-you-need-to-know-about-open-policy-agent-opa-and-terraform)
[50](https://terrateam.io/blog/opa-with-terraform)
[51](https://github.com/Scalr/sample-tf-opa-policies)
[52](https://developer.hashicorp.com/terraform/enterprise/policy-enforcement/define-policies/opa)
[53](https://dev.to/terrateam/building-a-cicd-pipeline-for-terraform-with-github-actions-step-by-step-guide-3dlp)
[54](https://dev.to/aws-builders/provisioning-aws-infrastructure-using-terraform-and-github-actions-40ei)
[55](https://developer.okta.com/blog/2024/10/11/terraform-ci-cd)
[56](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
[57](https://discuss.hashicorp.com/t/terraform-test-to-run-in-terraform-cloud-workspace/66956)
[58](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
[59](https://controlmonkey.io/terraform-cloud/)
[60](https://snyk.io/blog/infrastructure-drift-detection-mitigation/)
[61](https://spacelift.io/blog/drift-detection)
[62](https://www.linkedin.com/pulse/infrastructure-drift-iac-environments-practical-guide-ankush-madaan-cvycc)
[63](https://dev.to/spacelift/how-to-manage-cloud-infrastructure-drift-4f0)
[64](https://developer.hashicorp.com/terraform/tutorials/cloud/drift-detection)
[65](https://itnext.io/automating-tagging-and-versioning-of-terraform-modules-or-any-language-3a271966c63c)
[66](https://dustindortch.com/2024/02/29/terraform-best-practices-versioning/)
[67](https://discuss.hashicorp.com/t/module-version-semantics/10892)
[68](https://developer.hashicorp.com/terraform/plugin/best-practices/versioning)
[69](https://www.meegle.com/en_us/topics/infrastructure-as-code/testing-infrastructure-as-code-configurations)
[70](https://www.frugaltesting.com/blog/automating-cloud-testing-with-terraform-aws-the-complete-guide)
[71](https://www.techtarget.com/searchitoperations/tip/Infrastructure-as-code-testing-strategies-to-validate-a-deployment)
[72](https://www.stxnext.com/blog/why-test-infrastructure-as-code)
[73](https://techcommunity.microsoft.com/t5/azure-high-performance-computing/exploring-an-automated-testing-strategy-for-infrastructure-as/ba-p/3971715)
[74](https://spacelift.io/blog/terraform-best-practices)
[75](https://www.reddit.com/r/ExperiencedDevs/comments/1d6000k/infraascode_best_approaches_to_unit_and/)
[76](https://developer.hashicorp.com/terraform/language/tests)
[77](https://www.infralovers.com/blog/2025-02-11-methods-for-testing-terraform/)
[78](https://codefresh.io/learn/infrastructure-as-code/infrastructure-as-code-on-aws-process-tools-and-best-practices/)
[79](https://americanchase.com/terraform-modules-best-practices/)
[80](https://www.harness.io/harness-devops-academy/how-to-implement-infrastructure-as-code)
[81](https://developer.hashicorp.com/terraform/cli/commands/apply)
[82](https://github.com/gruntwork-io/terratest)
[83](https://developer.hashicorp.com/terraform/cli/run)
[84](https://github.com/Derek-Ashmore/terraform-testing-examples)
[85](https://www.darkraiden.com/blog/test-terraform-modules-with-terratest/)
[86](https://dev.to/af/terraform-workflow-write-plan-apply-512h)
[87](https://www.infracloud.io/blogs/testing-iac-terratest/)
[88](https://bitrise.io/blog/post/automating-the-setup-of-terraform-cloud-automations)
[89](https://www.withcoherence.com/articles/terraform-automation-best-practices)
[90](https://octopus.com/blog/smoke-testing-infrastructure-runbooks)
[91](https://terrateam.io/blog/terraform-pre-commit-hooks)
[92](https://www.frugaltesting.com/blog/smoke-testing-procedures-examples-and-best-practices)
[93](https://developer.hashicorp.com/terraform/language/state)
[94](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
[95](https://scalr.com/learning-center/understanding-detecting-infrastructure-drift-part-1/)
[96](https://www.reddit.com/r/Terraform/comments/1gyto9p/versioning_our_terraform_modules/)
[97](https://www.firefly.ai/academy/state-management-in-iac-best-practices-for-handling-terraform-state-files)
[98](https://dev.to/patdevops/advanced-terraform-module-usage-versioning-nesting-and-reuse-across-environments-43j0)
[99](https://www.reddit.com/r/Terraform/comments/15rhh77/best_way_to_isolate_terraform_state_files/)
[100](https://www.reddit.com/r/Terraform/comments/1f83cpa/unit_tests_via_mocking/)
[101](https://aws.amazon.com/blogs/infrastructure-and-automation/save-time-with-automated-security-checks-of-terraform-scripts/)
[102](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html)
[103](https://developer.hashicorp.com/terraform/tutorials/cloud/validation-enforcement)
[104](https://www.youtube.com/watch?v=fiS-mOYP42Q)
[105](https://www.checkov.io)
[106](https://aws.amazon.com/blogs/modernizing-with-aws/automate-microsoft-web-application-deployments-with-github-actions-and-terraform/)
[107](https://martinfowler.com/articles/practical-test-pyramid.html)
[108](https://www.browserstack.com/guide/testing-pyramid-for-test-automation)
[109](https://www.hashicorp.com/en/blog/7-ways-to-optimize-cloud-spend-with-terraform)
[110](https://terrateam.io/blog/ci-cd-pipeline-for-terraform)
[111](https://www.rainforestqa.com/blog/the-layers-of-testing-architecture)
[112](https://www.contino.io/insights/top-3-terraform-testing-strategies-for-ultra-reliable-infrastructure-as-code)
[113](https://www.youtube.com/watch?v=Ah17o_1bryo)
[114](https://qualityeng.substack.com/p/the-six-layers-of-testing)
[115](https://www.headspin.io/blog/regression-testing-a-complete-guide)
[116](https://dev.to/citrux-digital/how-to-manage-multiple-environments-with-terraform-using-workspaces-47o)
[117](https://dev.to/morrismoses149/what-to-include-in-a-regression-test-plan-3k06)
[118](https://www.technoblather.ca/supporting-staging-and-production-environments-with-terraform/)
[119](https://www.bytesnap.com/news-blog/what-is-regression-testing-guide/)
[120](https://www.gruntwork.io/blog/how-to-manage-multiple-environments-with-terraform-using-workspaces)
[121](https://www.linkedin.com/pulse/regression-rebuild-testing-your-infrastructure-code-kurtis-lamb)
[122](https://www.ibm.com/think/topics/regression-testing)
[123](https://discuss.hashicorp.com/t/workspaces-for-dev-test-prod-or-other-different-environments/13776)
[124](https://zeet.co/blog/terraform-test)
[125](https://github.com/resources/articles/regression-testing-definition-types-and-tools)
[126](https://www.reddit.com/r/devops/comments/1bs7vx8/how_to_promote_aws_terraform_from_staging_to_prod/)