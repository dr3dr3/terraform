# ADR-017: EKS Cluster and 1Password Secure Note Lifecycle Coordination

## Status

Approved

## Date

2025-12-03

## Context

We have two related Terraform configurations that need to be coordinated:

1. **EKS Cluster Provisioning** (`terraform/env-development/platform-layer/eks-auto-mode/`)
   - Provisions EKS clusters in development (and other environments)
   - Managed via GitHub Actions workflow (`terraform-dev-platform-eks.yml`)
   - Supports TTL-based auto-destroy via `eks-ttl-check.yml` workflow
   - Per ADR-014: API/GHA trigger with manual provisioning for learning environments

2. **1Password Secure Note Sync** (`terraform/env-management/foundation-layer/eks-cluster-admin/`)
   - Stores EKS cluster connection details in 1Password
   - Per ADR-016: Phase 1.2 - Terraform to 1Password Integration
   - Reads cluster outputs from Terraform Cloud state via `tfe_outputs`
   - Creates/updates secure notes for the eks-admin devcontainer

### Current Situation

These two configurations operate independently:

- **Provisioning**: EKS cluster is created via GitHub Actions, outputs available in Terraform Cloud
- **1Password Sync**: Must be run separately (currently CLI-driven, local execution only)
- **Destruction**: When EKS cluster is destroyed, the 1Password secure note becomes orphaned

### Problems

1. **Manual Coordination Required**: After EKS provisioning, someone must manually run eks-cluster-admin Terraform
2. **Orphaned Secure Notes**: When clusters are destroyed (manually or via TTL), 1Password items remain
3. **State Inconsistency**: 1Password may reference non-existent clusters
4. **TTL Cleanup Gap**: The `eks-ttl-check.yml` workflow destroys clusters but doesn't clean up 1Password

### Requirements

1. **Automatic Sync on Provision**: When EKS cluster is created, 1Password item should be created/updated
2. **Automatic Cleanup on Destroy**: When EKS cluster is destroyed, 1Password item should be deleted
3. **TTL-Aware**: Must work with TTL-based auto-destroy mechanism
4. **Security**: 1Password authentication must be secure (no long-lived tokens in CI)
5. **Minimal Changes**: Prefer solutions that don't require major refactoring
6. **Visibility**: Clear logging of what was created/deleted in 1Password

### Technical Constraints

The 1Password Terraform provider has two authentication modes:

1. **CLI Mode** (`service_account_token`): Requires `op` CLI binary installed - does NOT work in Terraform Cloud standard runners
2. **Connect Mode** (`url` + `token`): Uses 1Password Connect REST API - works anywhere but requires deploying a Connect server

Currently, eks-cluster-admin uses CLI Mode and runs locally.

## Decision Drivers

1. **Automation**: Minimize manual steps in EKS lifecycle
2. **Consistency**: 1Password should always reflect actual cluster state
3. **Cost Protection**: TTL mechanism must continue to work seamlessly
4. **Security**: No long-lived secrets in CI/CD
5. **Simplicity**: Prefer solutions using existing tools and patterns
6. **Learning Value**: Align with ADR-014's goal of practising different workflow patterns

## Options Considered

### Option 1: GitHub Actions Orchestration (Workflow Chaining)

Modify the EKS provisioning workflow to trigger eks-cluster-admin after successful apply/destroy.

#### Option 1 Implementation

```yaml
# .github/workflows/terraform-dev-platform-eks.yml (modified)

jobs:
  terraform-apply:
    # ... existing apply job ...
    outputs:
      cluster_created: ${{ steps.apply.outputs.cluster_created }}

  sync-1password:
    name: "Sync to 1Password"
    runs-on: ubuntu-latest
    needs: terraform-apply
    if: needs.terraform-apply.outputs.cluster_created == 'true'
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - name: Terraform Init (eks-cluster-admin)
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        run: terraform init
      
      - name: Terraform Apply (eks-cluster-admin)
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: terraform apply -auto-approve -var="sync_development_eks=true"

  terraform-destroy:
    # ... existing destroy job ...
    
  cleanup-1password:
    name: "Cleanup 1Password"
    runs-on: ubuntu-latest
    needs: terraform-destroy
    if: needs.determine-action.outputs.action == 'destroy'
    steps:
      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1
      
      - name: Delete 1Password Item
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          # Delete the secure note for this cluster
          op item delete "EKS-development-*" --vault Infrastructure || true
```

#### Option 1 Pros

✅ **Single Workflow**: All EKS lifecycle in one place

✅ **Guaranteed Ordering**: 1Password sync happens after successful EKS apply

✅ **Native GHA Features**: Uses workflow dependencies and outputs

✅ **TTL-Compatible**: Can add same pattern to eks-ttl-check.yml

✅ **Existing Patterns**: Similar to current EKS workflow structure

#### Option 1 Cons

❌ **1Password CLI Required**: Must install `op` CLI in runner

❌ **Service Account Token in CI**: Requires storing OP_SERVICE_ACCOUNT_TOKEN as secret

❌ **Mixed Concerns**: EKS workflow now also manages 1Password

❌ **Two Terraform Applies**: Longer workflow execution time

❌ **Duplicate Logic**: Same cleanup needed in both destroy and TTL-check workflows

---

### Option 2: Terraform Cloud Run Triggers

Configure Terraform Cloud workspace run triggers so eks-cluster-admin automatically runs after EKS workspace completes.

#### Option 2 Implementation

```hcl
# In terraform-cloud workspace configuration
resource "tfe_workspace" "eks_cluster_admin" {
  name              = "management-foundation-eks-cluster-admin"
  organization      = var.tfc_organization
  working_directory = "terraform/env-management/foundation-layer/eks-cluster-admin"
  
  # This workspace should NOT have VCS connection 
  # (CLI-driven per ADR-014 for foundation layer)
  
  # Run triggers - run this workspace after EKS workspaces
  # NOTE: This only triggers on successful applies, not destroys
}

resource "tfe_run_trigger" "eks_dev_to_admin" {
  workspace_id  = tfe_workspace.eks_cluster_admin.id
  sourceable_id = tfe_workspace.eks_development.id
}
```

#### Option 2 Pros

✅ **Native TFC Feature**: Built-in dependency management

✅ **No Workflow Changes**: EKS workflow unchanged

✅ **Automatic**: No manual intervention needed for creates

✅ **Terraform-Native**: Stays within Terraform ecosystem

#### Option 2 Cons

❌ **Create-Only**: Run triggers only fire on successful applies, not destroys

❌ **No Destroy Trigger**: Cannot automatically cleanup on EKS destruction

❌ **1Password CLI Issue**: Still can't run in TFC standard runners (needs `op` CLI)

❌ **TTL Cleanup Gap**: TTL-based destroys won't trigger 1Password cleanup

❌ **Partial Solution**: Only solves half the problem (create, not destroy)

---

### Option 3: 1Password Connect Server

Deploy a 1Password Connect server to enable the Terraform provider to work in any environment (including Terraform Cloud runners).

#### Option 3 Implementation

```hcl
# Deploy 1Password Connect in AWS
# terraform/env-management/foundation-layer/1password-connect/

resource "aws_ecs_task_definition" "onepassword_connect" {
  family                   = "onepassword-connect"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  
  container_definitions = jsonencode([
    {
      name  = "connect-api"
      image = "1password/connect-api:latest"
      portMappings = [{
        containerPort = 8080
      }]
      environment = [
        {
          name  = "OP_SESSION"
          value = "file:/run/secrets/1password-credentials.json"
        }
      ]
    },
    {
      name  = "connect-sync"
      image = "1password/connect-sync:latest"
      environment = [
        {
          name  = "OP_SESSION"
          value = "file:/run/secrets/1password-credentials.json"
        }
      ]
    }
  ])
}

# Then in eks-cluster-admin:
provider "onepassword" {
  url   = "https://connect.internal.example.com"
  token = var.op_connect_token
}
```

#### Option 3 Pros

✅ **Full TFC Compatibility**: Works in Terraform Cloud remote runners

✅ **VCS-Driven Possible**: Could enable VCS-driven workflow for eks-cluster-admin

✅ **REST API**: More stable than CLI-based approach

✅ **Centralized**: Single Connect server for all 1Password integrations

#### Option 3 Cons

❌ **Infrastructure Overhead**: Need to deploy and maintain Connect server

❌ **Cost**: ECS/Fargate costs for running Connect server 24/7

❌ **Complexity**: Additional infrastructure to secure and monitor

❌ **Still Needs Destroy Trigger**: Doesn't solve the destroy coordination problem

❌ **Overkill**: Significant investment for this single use case

❌ **Security Surface**: Connect server becomes critical infrastructure to protect

---

### Option 4: Composite GitHub Action with Reusable Workflow

Create a reusable workflow that handles 1Password sync, called from both EKS and TTL-check workflows.

#### Option 4 Implementation

```yaml
# .github/workflows/reusable-1password-eks-sync.yml
name: "Reusable: 1Password EKS Sync"

on:
  workflow_call:
    inputs:
      action:
        description: "sync or cleanup"
        required: true
        type: string
      environment:
        description: "development, staging, production"
        required: true
        type: string
      cluster_name:
        description: "Name of the EKS cluster"
        required: false
        type: string
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN:
        required: true
      TF_API_TOKEN:
        required: true

jobs:
  sync-1password:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1
      
      - name: Sync to 1Password (Create/Update)
        if: inputs.action == 'sync'
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          # Fetch cluster details from TFC outputs
          CLUSTER_NAME="${{ inputs.cluster_name }}"
          ENVIRONMENT="${{ inputs.environment }}"
          
          # Use 1Password CLI to create/update item
          op item create \
            --vault "Infrastructure" \
            --category "secure_note" \
            --title "EKS-${ENVIRONMENT}-${CLUSTER_NAME}" \
            --tags "EKS,Kubernetes,${ENVIRONMENT},Terraform-Managed" \
            "cluster_name=${CLUSTER_NAME}" \
            "cluster_region=ap-southeast-2" \
            2>/dev/null || \
          op item edit "EKS-${ENVIRONMENT}-${CLUSTER_NAME}" \
            "cluster_name=${CLUSTER_NAME}"
      
      - name: Cleanup 1Password (Delete)
        if: inputs.action == 'cleanup'
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          ENVIRONMENT="${{ inputs.environment }}"
          op item list --vault "Infrastructure" --format json | \
            jq -r ".[] | select(.title | startswith(\"EKS-${ENVIRONMENT}-\")) | .title" | \
            while read -r ITEM_TITLE; do
              echo "Deleting 1Password item: $ITEM_TITLE"
              op item delete "$ITEM_TITLE" --vault "Infrastructure" || true
            done
```

```yaml
# .github/workflows/terraform-dev-platform-eks.yml (modified)
  
  terraform-apply:
    # ... existing steps ...
    outputs:
      cluster_name: ${{ steps.outputs.outputs.cluster_name }}
  
  sync-1password-on-apply:
    needs: terraform-apply
    if: needs.determine-action.outputs.action == 'apply'
    uses: ./.github/workflows/reusable-1password-eks-sync.yml
    with:
      action: sync
      environment: development
      cluster_name: ${{ needs.terraform-apply.outputs.cluster_name }}
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
  
  cleanup-1password-on-destroy:
    needs: terraform-destroy
    if: needs.determine-action.outputs.action == 'destroy'
    uses: ./.github/workflows/reusable-1password-eks-sync.yml
    with:
      action: cleanup
      environment: development
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
```

```yaml
# .github/workflows/eks-ttl-check.yml (modified)
  
  destroy-development:
    # ... existing destroy steps ...
  
  cleanup-1password-on-ttl:
    needs: destroy-development
    uses: ./.github/workflows/reusable-1password-eks-sync.yml
    with:
      action: cleanup
      environment: development
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
```

#### Option 4 Pros

✅ **DRY Principle**: Single reusable workflow for 1Password operations

✅ **Works with TTL**: Same workflow called from TTL-check

✅ **Consistent**: Same cleanup logic everywhere

✅ **1Password CLI Approach**: Uses existing CLI mode (no Connect server needed)

✅ **Flexible**: Can be called with different actions and parameters

✅ **Testable**: Reusable workflow can be tested independently

#### Option 4 Cons

❌ **Service Account Token in CI**: Still requires OP_SERVICE_ACCOUNT_TOKEN secret

❌ **CLI-Based**: Uses 1Password CLI directly (not Terraform-managed)

❌ **State Drift Risk**: 1Password state not managed by Terraform state

❌ **Multiple Workflow Files**: Need to update multiple callers

---

### Option 5: Terraform-Managed Lifecycle with Conditional Resources

Use Terraform's native lifecycle management by making eks-cluster-admin aware of cluster existence.

#### Option 5 Implementation

```hcl
# terraform/env-management/foundation-layer/eks-cluster-admin/main.tf

# Check if cluster exists by querying TFC workspace state
data "tfe_outputs" "eks_development" {
  count = var.sync_development_eks ? 1 : 0

  organization = var.tfc_organization
  workspace    = var.eks_development_workspace
}

locals {
  # Cluster exists if outputs are non-empty
  dev_cluster_exists = (
    var.sync_development_eks && 
    length(data.tfe_outputs.eks_development) > 0 &&
    try(data.tfe_outputs.eks_development[0].values.cluster_name, "") != ""
  )
}

# Only create 1Password item if cluster exists
resource "onepassword_item" "eks_development" {
  count = local.dev_cluster_exists ? 1 : 0
  
  vault    = data.onepassword_vault.infrastructure.uuid
  category = "secure_note"
  title    = "EKS-development-${local.dev_cluster_name}"
  # ... rest of configuration
}
```

**Coordination via GitHub Actions:**

```yaml
# Run eks-cluster-admin after every EKS operation (apply or destroy)
# The Terraform will handle creating or destroying the 1Password item
# based on whether the cluster exists

  sync-1password:
    needs: [terraform-apply, terraform-destroy]
    if: always() && (needs.terraform-apply.result == 'success' || needs.terraform-destroy.result == 'success')
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - name: Terraform Init
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        run: terraform init
      
      - name: Terraform Apply
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          # Terraform will create item if cluster exists
          # or destroy item if cluster doesn't exist (count = 0)
          terraform apply -auto-approve
```

#### Option 5 Pros

✅ **Terraform-Managed**: 1Password state managed by Terraform

✅ **Idempotent**: Running apply multiple times is safe

✅ **Self-Healing**: If cluster is deleted, next apply removes 1Password item

✅ **Single Source of Truth**: Terraform determines state

✅ **Existing Pattern**: Uses existing eks-cluster-admin configuration

✅ **TTL-Compatible**: Same approach works after TTL-based destroy

#### Option 5 Cons

❌ **Two Applies**: Need to run eks-cluster-admin after every EKS operation

❌ **1Password CLI Required**: Still needs `op` CLI in runner

❌ **Cross-Workspace Dependency**: eks-cluster-admin depends on EKS workspace state

❌ **Timing Sensitivity**: Must wait for EKS state to be available

❌ **Error Handling**: If eks-cluster-admin fails, 1Password may be inconsistent

---

### Option 6: Event-Driven with AWS EventBridge

Use AWS EventBridge to detect EKS cluster state changes and trigger Lambda to update 1Password.

#### Option 6 Implementation

```hcl
# terraform/env-management/foundation-layer/1password-sync/

# EventBridge rule for EKS cluster creation
resource "aws_cloudwatch_event_rule" "eks_created" {
  name        = "eks-cluster-created"
  description = "Capture EKS cluster creation events"
  
  event_pattern = jsonencode({
    source      = ["aws.eks"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["eks.amazonaws.com"]
      eventName   = ["CreateCluster"]
    }
  })
}

# EventBridge rule for EKS cluster deletion
resource "aws_cloudwatch_event_rule" "eks_deleted" {
  name        = "eks-cluster-deleted"
  description = "Capture EKS cluster deletion events"
  
  event_pattern = jsonencode({
    source      = ["aws.eks"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["eks.amazonaws.com"]
      eventName   = ["DeleteCluster"]
    }
  })
}

# Lambda function to sync 1Password
resource "aws_lambda_function" "onepassword_sync" {
  function_name = "eks-onepassword-sync"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  
  environment {
    variables = {
      OP_SERVICE_ACCOUNT_TOKEN = var.op_service_account_token  # From secrets manager
      OP_VAULT                 = "Infrastructure"
    }
  }
}

resource "aws_cloudwatch_event_target" "eks_to_lambda" {
  rule      = aws_cloudwatch_event_rule.eks_created.name
  target_id = "OnePasswordSync"
  arn       = aws_lambda_function.onepassword_sync.arn
}
```

```python
# Lambda function
import boto3
import subprocess
import json
import os

def handler(event, context):
    event_name = event['detail']['eventName']
    cluster_name = event['detail']['requestParameters']['name']
    region = event['region']
    
    if event_name == 'CreateCluster':
        # Wait for cluster to be active
        eks = boto3.client('eks', region_name=region)
        waiter = eks.get_waiter('cluster_active')
        waiter.wait(name=cluster_name)
        
        # Get cluster details
        cluster = eks.describe_cluster(name=cluster_name)['cluster']
        
        # Create 1Password item using CLI
        create_1password_item(cluster)
        
    elif event_name == 'DeleteCluster':
        # Delete 1Password item
        delete_1password_item(cluster_name)
    
    return {'statusCode': 200}

def create_1password_item(cluster):
    # Use 1Password CLI (bundled in Lambda layer)
    cmd = [
        'op', 'item', 'create',
        '--vault', os.environ['OP_VAULT'],
        '--category', 'secure_note',
        '--title', f"EKS-{cluster['tags'].get('Environment', 'unknown')}-{cluster['name']}",
        f"cluster_name={cluster['name']}",
        f"cluster_endpoint={cluster['endpoint']}",
        f"cluster_arn={cluster['arn']}"
    ]
    subprocess.run(cmd, env={**os.environ})
```

#### Option 6 Pros

✅ **Real-Time**: Triggers immediately on AWS events

✅ **Decoupled**: No changes to EKS or GitHub Actions workflows

✅ **Automatic**: No manual intervention needed

✅ **Catches All**: Works regardless of how cluster was created/destroyed

✅ **TTL-Compatible**: TTL destroys trigger same EventBridge rules

✅ **AWS-Native**: Uses standard AWS event patterns

#### Option 6 Cons

❌ **Infrastructure Overhead**: Need Lambda, EventBridge, IAM roles

❌ **1Password CLI in Lambda**: Need to bundle `op` CLI in Lambda layer

❌ **Cross-Account Complexity**: EKS events in dev account, Lambda in management

❌ **Not Terraform-Managed**: 1Password state outside Terraform

❌ **Debugging Complexity**: Distributed system harder to troubleshoot

❌ **Delay**: CloudTrail events have slight delay (minutes)

❌ **Cost**: Additional Lambda invocations and EventBridge rules

---

## Comparison Matrix

| Criterion | Option 1: GHA Orchestration | Option 2: TFC Run Triggers | Option 3: Connect Server | Option 4: Reusable Workflow | Option 5: Terraform Lifecycle | Option 6: EventBridge |
|-----------|---------------------------|---------------------------|-------------------------|---------------------------|------------------------------|----------------------|
| **Create Coordination** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Destroy Coordination** | ✅ Yes | ❌ No | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **TTL-Compatible** | ⚠️ Manual | ❌ No | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Implementation Effort** | Low | Low | High | Medium | Low | High |
| **Maintenance Effort** | Low | Low | High | Low | Low | Medium |
| **Infrastructure Required** | None | None | ECS/Fargate | None | None | Lambda + EventBridge |
| **Terraform-Managed** | ❌ No | ⚠️ Partial | ⚠️ Partial | ❌ No | ✅ Yes | ❌ No |
| **1Password CLI Required** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Security** | Medium | Medium | Medium | Medium | Medium | Medium |
| **Complexity** | Low | Low | High | Medium | Low | High |
| **Learning Value** | Medium | Low | High | Medium | High | High |

## Decision

### Recommended: Option 5 - Terraform-Managed Lifecycle with Conditional Resources

This option provides the best balance of:

1. **Terraform-Native**: State management through Terraform
2. **Simple Implementation**: Uses existing eks-cluster-admin configuration
3. **TTL-Compatible**: Works with TTL-based auto-destroy
4. **Consistency**: Single workflow pattern for all scenarios
5. **ADR Alignment**: Maintains CLI-driven approach for foundation layer (per ADR-014)

### Implementation Strategy

#### Phase 1: Update eks-cluster-admin for Conditional Creation (Week 1)

Modify `locals.tf` to detect cluster existence:

```hcl
# terraform/env-management/foundation-layer/eks-cluster-admin/locals.tf

locals {
  # Development cluster - check if outputs exist and are non-empty
  dev_cluster_exists = (
    var.sync_development_eks &&
    length(data.tfe_outputs.eks_development) > 0 &&
    try(data.tfe_outputs.eks_development[0].values.cluster_name, "") != ""
  )
  
  dev_cluster_name     = local.dev_cluster_exists ? data.tfe_outputs.eks_development[0].values.cluster_name : ""
  dev_cluster_endpoint = local.dev_cluster_exists ? data.tfe_outputs.eks_development[0].values.cluster_endpoint : ""
  dev_cluster_arn      = local.dev_cluster_exists ? data.tfe_outputs.eks_development[0].values.cluster_arn : ""
  dev_oidc_issuer_url  = local.dev_cluster_exists ? data.tfe_outputs.eks_development[0].values.cluster_oidc_issuer_url : ""
  
  # Similar patterns for staging, production, sandbox...
}
```

Update `main.tf` to use conditional count:

```hcl
# terraform/env-management/foundation-layer/eks-cluster-admin/main.tf

resource "onepassword_item" "eks_development" {
  count = local.dev_cluster_exists ? 1 : 0  # Changed from var.sync_development_eks
  
  vault    = data.onepassword_vault.infrastructure.uuid
  category = "secure_note"
  title    = "EKS-development-${local.dev_cluster_name}"
  # ... rest unchanged
}
```

#### Phase 2: Create Reusable 1Password Sync Workflow (Week 1)

```yaml
# .github/workflows/reusable-1password-eks-sync.yml
name: "Reusable: Sync EKS to 1Password"

on:
  workflow_call:
    inputs:
      environment:
        description: "Target environment (development, staging, production, sandbox)"
        required: true
        type: string
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN:
        required: true
      TF_API_TOKEN:
        required: true

jobs:
  sync:
    name: "Sync 1Password"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Install 1Password CLI
        uses: 1password/install-cli-action@v1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - name: Terraform Init
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        run: terraform init
      
      - name: Terraform Apply
        working-directory: terraform/env-management/foundation-layer/eks-cluster-admin
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          # Enable sync for the target environment
          terraform apply -auto-approve \
            -var="sync_${{ inputs.environment }}_eks=true"
      
      - name: Summary
        run: |
          echo "## 1Password Sync Complete 🔐" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Environment: ${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "The 1Password secure note has been synced based on current EKS cluster state." >> $GITHUB_STEP_SUMMARY
```

#### Phase 3: Integrate into EKS Provisioning Workflow (Week 2)

```yaml
# .github/workflows/terraform-dev-platform-eks.yml (additions)

jobs:
  # ... existing jobs ...

  sync-1password:
    name: "Sync 1Password"
    needs: [determine-action, terraform-apply, terraform-destroy]
    if: |
      always() && 
      (needs.terraform-apply.result == 'success' || needs.terraform-destroy.result == 'success')
    uses: ./.github/workflows/reusable-1password-eks-sync.yml
    with:
      environment: development
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
```

#### Phase 4: Integrate into TTL Check Workflow (Week 2)

```yaml
# .github/workflows/eks-ttl-check.yml (additions)

jobs:
  # ... existing jobs ...

  sync-1password-after-ttl-destroy:
    name: "Sync 1Password (Post-TTL Cleanup)"
    needs: destroy-development
    if: needs.destroy-development.result == 'success'
    uses: ./.github/workflows/reusable-1password-eks-sync.yml
    with:
      environment: development
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
      TF_API_TOKEN: ${{ secrets.TF_API_TOKEN }}
```

#### Phase 5: Add 1Password Service Account Secret (Week 1)

Add the required secret to GitHub:

```bash
# Create 1Password Service Account with access to "terraform"" vault
# Then add to GitHub repository secrets:
gh secret set OP_SERVICE_ACCOUNT_TOKEN --body "ops_..."
```

### Workflow Diagram

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EKS Cluster Lifecycle                               │
└─────────────────────────────────────────────────────────────────────────────┘

  Manual Trigger                    TTL Expiration
  (workflow_dispatch)               (eks-ttl-check.yml)
         │                                 │
         ▼                                 ▼
┌─────────────────┐              ┌─────────────────┐
│  terraform-dev- │              │  eks-ttl-check  │
│  platform-eks   │              │  workflow       │
└────────┬────────┘              └────────┬────────┘
         │                                │
    ┌────┴────┐                           │
    │         │                           │
    ▼         ▼                           ▼
┌───────┐ ┌───────┐              ┌───────────────┐
│ Apply │ │Destroy│              │ TTL Destroy   │
└───┬───┘ └───┬───┘              └───────┬───────┘
    │         │                          │
    └────┬────┘                          │
         │                               │
         ▼                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    reusable-1password-eks-sync.yml                          │
│                                                                             │
│  1. Checkout repository                                                     │
│  2. Install 1Password CLI                                                   │
│  3. terraform init (eks-cluster-admin)                                      │
│  4. terraform apply                                                         │
│     - If cluster exists → Creates/Updates 1Password item                    │
│     - If cluster gone → Destroys 1Password item (count = 0)                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           1Password Vault                                   │
│                             "terraform"                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ EKS-development-dev-eks-cluster                                     │    │
│  │   cluster_name: dev-eks-cluster                                     │    │
│  │   cluster_endpoint: https://...eks.amazonaws.com                    │    │
│  │   cluster_region: ap-southeast-2                                    │    │
│  │   ...                                                               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

✅ **Automated Lifecycle**: 1Password items created and destroyed automatically with EKS clusters

✅ **Terraform-Managed**: State managed through Terraform, not ad-hoc scripts

✅ **Single Pattern**: Same reusable workflow for all triggers (manual, push, TTL)

✅ **TTL-Compatible**: Seamlessly integrates with TTL-based auto-destroy

✅ **ADR-014 Aligned**: Maintains CLI-driven approach for foundation layer

✅ **ADR-016 Aligned**: Continues Phase 1.2 implementation

✅ **Idempotent**: Running sync multiple times is safe

✅ **Self-Healing**: If cluster state changes, next sync corrects 1Password

✅ **Minimal Changes**: Builds on existing configurations

✅ **Clear Audit Trail**: GitHub Actions logs show all sync operations

### Negative

❌ **Secret Management**: Requires OP_SERVICE_ACCOUNT_TOKEN in GitHub Secrets

❌ **1Password CLI Dependency**: Must install CLI in GitHub Actions runner

❌ **Sequential Operations**: EKS apply must complete before 1Password sync starts

❌ **Cross-Workspace Coupling**: eks-cluster-admin depends on EKS workspace state availability

❌ **Workflow Complexity**: EKS workflow now includes 1Password sync job

### Neutral

⚪ **Additional Workflow Time**: ~1-2 minutes added for 1Password sync

⚪ **Learning Curve**: Team needs to understand the coordination mechanism

⚪ **Testing Needed**: Must verify sync works in all scenarios

## Security Considerations

### 1Password Service Account Token

- **Storage**: GitHub Secrets (encrypted at rest)
- **Scope**: Read/write access to Infrastructure vault only
- **Rotation**: Rotate annually or after team member changes
- **Audit**: 1Password logs all operations by service account

### Least Privilege

- Service account only has access to Infrastructure vault
- Cannot access personal vaults or other shared vaults
- Token is not logged in GitHub Actions output

### Alternative: Environment-Specific Tokens

Consider separate tokens per environment:

- `OP_SERVICE_ACCOUNT_TOKEN_DEV` - Development vault access only
- `OP_SERVICE_ACCOUNT_TOKEN_STAGING` - Staging vault access only

This limits blast radius if a token is compromised.

## Alternatives Not Chosen

### Why Not Option 3: 1Password Connect Server

**Why Not**: Significant infrastructure overhead (ECS/Fargate) for a single use case. The CLI-based approach works well for GitHub Actions.

**When to Reconsider**: If multiple Terraform configurations need 1Password access from Terraform Cloud remote runners.

### Option 6: EventBridge

**Why Not**: Cross-account event routing complexity, Lambda packaging complexity (bundling `op` CLI), and debugging distributed systems.

**When to Reconsider**: If EKS clusters are created/destroyed through means other than Terraform (e.g., console, SDK).

## Related Decisions

- **ADR-014**: Terraform Workspace Triggers (defines CLI-driven for foundation layer)
- **ADR-016**: EKS Credentials Cross-Repo Access (defines 1Password integration)
- **ADR-012**: Automated Resource Cleanup (TTL patterns for sandbox)

## Future Considerations

1. **Multi-Environment Support**: Extend pattern to staging/production EKS clusters
2. **1Password Connect**: If multiple TFC workspaces need 1Password, consider Connect server
3. **Event-Driven Enhancement**: Add EventBridge as backup for missed sync scenarios
4. **Notification Enhancement**: Slack/Teams notification when 1Password items change

## Implementation Checklist

- [ ] Update `eks-cluster-admin/locals.tf` with cluster existence checks
- [ ] Update `eks-cluster-admin/main.tf` with conditional resource counts
- [ ] Create `reusable-1password-eks-sync.yml` workflow
- [ ] Add `OP_SERVICE_ACCOUNT_TOKEN` to GitHub Secrets
- [ ] Update `terraform-dev-platform-eks.yml` to call sync workflow
- [ ] Update `eks-ttl-check.yml` to call sync workflow after destroy
- [ ] Test: Manual EKS provision → verify 1Password item created
- [ ] Test: Manual EKS destroy → verify 1Password item deleted
- [ ] Test: TTL-based destroy → verify 1Password item deleted
- [ ] Update documentation (eks-cluster-admin README)

## References

- [1Password Terraform Provider Documentation](https://developer.1password.com/docs/terraform/)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [1Password GitHub Actions Integration](https://developer.1password.com/docs/ci-cd/github-actions/)
- [GitHub Actions Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Terraform tfe_outputs Data Source](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/data-sources/outputs)

---

**Version**: 1.0
**Author**: Platform Engineering Team
**Reviewers**: [To be assigned]
**Next Review**: After implementation (estimated: 2 weeks)
