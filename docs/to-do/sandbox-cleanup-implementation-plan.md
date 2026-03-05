# Sandbox Automated Cleanup — Implementation Plan

> **ADR:** [ADR-012: Automated Resource Cleanup for Sandbox Environment](../reference/architecture-decision-register/ADR-012-sandbox-automated-cleanup.md)
>
> **Status:** ADR is _Proposed_ — this plan is ready to execute once ADR-012 is approved.
>
> **Decision to implement:** Hybrid two-tier approach — Terraform Destroy (Tier 1) + AWS Nuke v3 (Tier 2)

---

## Overview

Without automated cleanup, the Sandbox account accumulates costs and resource clutter from experiments. The hybrid strategy:

- **Tier 1 — `terraform destroy`**: Scheduled GitHub Actions workflow detects expired Terraform workspaces (via `ExpiresOn` tag/variable) and destroys them cleanly via Terraform state
- **Tier 2 — AWS Nuke v3**: Runs after Tier 1, sweeps up any non-Terraform resources (Console-created, orphaned, manual experiments) older than 7 days

Tier 1 runs first because Terraform understands resource dependencies and handles deletion order correctly. Tier 2 is a safety net for everything else.

---

## Prerequisites

Before starting implementation:

- [ ] ADR-012 status changed from _Proposed_ to _Approved_ (request a review from the platform team)
- [ ] Sandbox AWS account ID confirmed: `898468025925`
- [ ] Sandbox `sandbox-foundation-iam-roles` workspace is applied (required for OIDC auth from GHA)
- [ ] GitHub repository secret `AWS_ROLE_ARN_SANDBOX` exists (GHA OIDC role ARN for sandbox)

---

## Phase 1 — Terraform Destroy Workflow (Week 1)

### Goal

Automatically run `terraform destroy` on sandbox Terraform workspaces that have expired.

### Step 1.1 — Establish `ExpiresOn` convention

All sandbox Terraform stacks should declare an expiry date. Add a local or variable to each sandbox stack:

```hcl
# terraform/env-sandbox/{layer}/{component}/main.tf
locals {
  expires_on = "2026-04-01"  # ISO 8601 date when this stack should be destroyed
}
```

Alternatively, add it as a tag on a sentinel resource and also set it in a `terraform.tfvars` file.

- [ ] Document the `ExpiresOn` convention in [`docs/reference/terraform-code-summary.md`](../reference/terraform-code-summary.md)
- [ ] Add `expires_on` local to all existing stacks under `terraform/env-sandbox/`

### Step 1.2 — Create the cleanup GitHub Actions workflow

Create `.github/workflows/sandbox-terraform-cleanup.yml`:

```yaml
name: "Sandbox: Terraform Cleanup"

on:
  schedule:
    - cron: "0 1 * * *"  # 1 AM UTC daily (before AWS Nuke)
  workflow_dispatch:
    inputs:
      dry_run:
        description: "Dry run (print what would be destroyed, don't actually destroy)"
        type: boolean
        default: true

permissions:
  id-token: write
  contents: read

jobs:
  find-expired:
    name: "Find Expired Workspaces"
    runs-on: ubuntu-latest
    outputs:
      workspaces: ${{ steps.find.outputs.workspaces }}
    steps:
      - uses: actions/checkout@v4
      - name: Find expired Terraform workspaces
        id: find
        run: |
          TODAY=$(date -u +%Y-%m-%d)
          EXPIRED=$(find terraform/env-sandbox -name "*.tf" | \
            xargs grep -l 'expires_on' | while read f; do
              VAL=$(grep -oP 'expires_on\s*=\s*"\K[^"]+' "$f" || true)
              if [[ -n "$VAL" && "$VAL" < "$TODAY" ]]; then
                dirname "$f"
              fi
            done | sort -u | jq -R -s -c 'split("\n")[:-1]')
          echo "workspaces=$EXPIRED" >> $GITHUB_OUTPUT
          echo "Expired workspaces: $EXPIRED"

  destroy:
    name: "Destroy ${{ matrix.workspace }}"
    needs: find-expired
    if: needs.find-expired.outputs.workspaces != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        workspace: ${{ fromJson(needs.find-expired.outputs.workspaces) }}
      fail-fast: false  # Try all workspaces even if one fails
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_SANDBOX }}
          role-session-name: sandbox-cleanup-${{ github.run_id }}
          aws-region: ap-southeast-2
      - uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      - name: Terraform Init
        working-directory: ${{ matrix.workspace }}
        run: terraform init
      - name: Terraform Destroy (dry run)
        if: inputs.dry_run == true
        working-directory: ${{ matrix.workspace }}
        run: terraform plan -destroy -no-color
      - name: Terraform Destroy
        if: inputs.dry_run != true
        working-directory: ${{ matrix.workspace }}
        run: terraform destroy -auto-approve -input=false
```

- [ ] Create the workflow file at `.github/workflows/sandbox-terraform-cleanup.yml`
- [ ] Test with `dry_run: true` via `gh workflow run`
- [ ] Confirm no false positives before enabling scheduled run

### Step 1.3 — Create Terraform infrastructure for the workflow

The cleanup workflow needs a GHA OIDC role in the sandbox account. Check if one exists:

```bash
aws --profile sandbox iam list-roles | grep sandbox
```

If not, create `terraform/env-sandbox/foundation-layer/gha-oidc/` following the pattern in `terraform/env-development/foundation-layer/gha-oidc/`.

- [ ] Verify or create `sandbox-foundation-gha-oidc` IAM role
- [ ] Add `AWS_ROLE_ARN_SANDBOX` secret to GitHub repository settings
- [ ] Create corresponding Terraform Cloud workspace in `workspaces.tf`

---

## Phase 2 — AWS Nuke Integration (Week 2)

### Goal

After Terraform-managed resources are destroyed by Tier 1, use AWS Nuke v3 to clean up everything else in the Sandbox account: Console-created resources, orphaned experiments, anything not managed by Terraform.

### Step 2.1 — Create the AWS Nuke configuration

Create `terraform/env-sandbox/sandbox-layer/aws-nuke/nuke-config.yaml`:

```yaml
# AWS Nuke v3 configuration for Sandbox account
# See: https://github.com/ekristen/aws-nuke

regions:
  - ap-southeast-2
  - us-east-1

account-blocklist:
  - "169506999567"  # Management — NEVER nuke
  - "126350206316"  # Development — NEVER nuke
  - "163436765579"  # Staging — NEVER nuke
  - "820485071161"  # Production — NEVER nuke

accounts:
  "898468025925":  # Sandbox — ONLY account where nuke runs
    filters:
      # Protect ALL Terraform-managed resources
      # Terraform tags everything with ManagedBy=Terraform
      IAMRole:
        - property: tag:ManagedBy
          value: "Terraform"
      IAMRolePolicy:
        - property: tag:ManagedBy
          value: "Terraform"
      # Protect resources explicitly marked
      EC2Instance:
        - property: tag:Protected
          value: "true"
      # Keep resources newer than 7 days (not yet expired)
      EC2Instance:
        - type: dateOlderThan
          property: LaunchTime
          value: "7d"
          invert: true  # Keep if YOUNGER than 7 days
      # Protect the cleanup infrastructure itself
      IAMRole:
        - type: glob
          value: "sandbox-cleanup-*"
      IAMRole:
        - type: glob
          value: "terraform-*"
      # Protect the OIDC provider
      IAMOIDCProvider:
        - type: glob
          value: "*"  # Keep all OIDC providers (managed by Terraform)
```

- [ ] Create `terraform/env-sandbox/sandbox-layer/aws-nuke/` folder
- [ ] Write `nuke-config.yaml` based on template above, tailored to which resource types you use in sandbox
- [ ] Add `terraform/env-sandbox/sandbox-layer/aws-nuke/aws-nuke-config.tfvars.example` for any variable values

### Step 2.2 — Create the AWS Nuke GitHub Actions workflow

Create `.github/workflows/sandbox-aws-nuke.yml`:

```yaml
name: "Sandbox: AWS Nuke Cleanup"

on:
  schedule:
    - cron: "0 2 * * *"  # 2 AM UTC daily (after Terraform cleanup at 1 AM)
  workflow_dispatch:
    inputs:
      dry_run:
        description: "Dry run only (list what would be deleted)"
        type: boolean
        default: true

permissions:
  id-token: write
  contents: read

jobs:
  nuke:
    name: "AWS Nuke Sandbox"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_SANDBOX }}
          role-session-name: sandbox-nuke-${{ github.run_id }}
          aws-region: ap-southeast-2

      - name: Install AWS Nuke v3
        run: |
          VERSION="v3.28.0"
          curl -Lo aws-nuke.tar.gz \
            "https://github.com/ekristen/aws-nuke/releases/download/${VERSION}/aws-nuke-${VERSION}-linux-amd64.tar.gz"
          tar -xzf aws-nuke.tar.gz
          chmod +x aws-nuke
          sudo mv aws-nuke /usr/local/bin/

      - name: Run AWS Nuke (dry run)
        if: inputs.dry_run == true || github.event_name == 'schedule'
        run: |
          aws-nuke run \
            --config terraform/env-sandbox/sandbox-layer/aws-nuke/nuke-config.yaml \
            --dry-run \
            --no-prompt

      - name: Run AWS Nuke (destructive)
        if: inputs.dry_run == false && github.event_name == 'workflow_dispatch'
        run: |
          aws-nuke run \
            --config terraform/env-sandbox/sandbox-layer/aws-nuke/nuke-config.yaml \
            --no-prompt
```

> **Important:** The scheduled run always uses `--dry-run` initially. Switch to destructive mode only via manual `workflow_dispatch` after reviewing dry-run output.

- [ ] Create the workflow file at `.github/workflows/sandbox-aws-nuke.yml`
- [ ] Run manually with `dry_run: true` and review the output carefully
- [ ] Verify the filter list protects all Terraform-managed resources
- [ ] Enable destructive mode for scheduled runs only after validation

### Step 2.3 — IAM permissions for AWS Nuke

AWS Nuke needs broad delete permissions in the Sandbox account. Create an IAM role:

- [ ] Add an `aws-nuke` IAM role to `terraform/env-sandbox/foundation-layer/iam-roles-terraform/` (or `gha-oidc/`)
- [ ] The role needs `*:Delete*`, `*:Terminate*`, `*:Remove*` across all services used in sandbox
- [ ] Scope trust policy to GitHub Actions with the specific workflow path

---

## Phase 3 — Notifications & Monitoring (Week 2-3)

### Goal

The team should know what was cleaned up and be alerted if cleanup fails.

- [ ] Create an SNS topic in the Sandbox account: `sandbox-cleanup-notifications`
- [ ] Subscribe the platform team email to the SNS topic
- [ ] Add SNS publish step to both GHA workflows (post summary to SNS)
- [ ] Add GHA job failure notification via Slack or email (use `if: failure()` step)
- [ ] Create a CloudWatch dashboard in the Sandbox account showing cleanup history

---

## Phase 4 — Guardrails & Documentation (Week 3)

### Goal

Make the system safe to run and easy to understand.

- [ ] Add a `sandbox-cleanup-protected` IAM permission boundary to prevent cleanup roles from deleting each other
- [ ] Create `docs/how-to-guides/sandbox-experiments.md` explaining:
  - How to create a sandbox experiment with an `expires_on` date
  - How to protect a resource from cleanup (`Protected=true` tag or `AutoCleanup=false`)
  - How to extend an experiment's expiry date
  - How to trigger an early cleanup manually
- [ ] Update `docs/reference/terraform-code-summary.md` to include the new sandbox cleanup workspaces
- [ ] Add Sandbox cleanup runbook to `docs/how-to-guides/`

---

## Approval Checklist

Before deploying any destructive runs:

- [ ] Dry-run output reviewed by at least two team members
- [ ] All Terraform-managed resources confirmed as protected in nuke config
- [ ] OIDC provider, IAM cleanup roles confirmed as protected
- [ ] Account block-list confirmed (management, dev, staging, prod IDs all present)
- [ ] Sandbox account alias set (AWS Nuke v3 requires an account alias as a safety check)
- [ ] Notification system tested (SNS topic receives test message)
- [ ] Emergency stop procedure documented (disabling the scheduled workflow)

---

## Cost Impact (Expected)

Once running, the cleanup should reduce sandbox costs by:

- Eliminating idle EKS clusters left running overnight: ~$0.10/hr per cluster
- Removing orphaned RDS instances: $0.02–$0.20/hr per instance
- Cleaning up NAT Gateways: $0.045/hr per gateway
- Estimated monthly savings after consistent cleanup: **$50–$300** depending on experiment frequency

---

## Related Documents

- [ADR-012: Sandbox Automated Cleanup](../reference/architecture-decision-register/ADR-012-sandbox-automated-cleanup.md)
- [ADR-011: Sandbox Environment](../reference/architecture-decision-register/ADR-011-sandbox-environment.md)
- [ADR-013: GHA IAM Role for EKS](../reference/architecture-decision-register/ADR-013-gha-aim-role-for-eks.md)
- [`.github/workflows/README.md`](../../.github/workflows/README.md)
