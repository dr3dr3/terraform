# Terraform Testing Options

## Overview

Testing Terraform infrastructure code is critical for stability, security, and cost-effectiveness. This document outlines common test types, mature tools, optimal strategies, cost-saving practices, and exit criteria for Terraform CI/CD pipelines.[3][5][6][7]

***

## Test Types

- **Static Analysis/Linting**
  - Ensures code quality and security without creating resources.
  - Tools: `terraform validate`, `terraform fmt`, TFLint, Checkov.
- **Unit & Contract Tests**
  - Validates individual module/resource logic, inputs, and outputs.
  - Tool: Terraform test framework (`*.tftest.hcl`).
- **Integration Tests**
  - Provisions real cloud resources in isolated environments; validates interaction between modules/resources.
  - Tools: Terratest (Go), Kitchen-Terraform (Ruby).
- **End-to-End Testing**
  - Verifies full architecture and end-user workflows across multiple modules.
  - Tools: Custom scripts, Terratest.
- **Compliance & Security Tests**
  - Enforces policies, compliance rules, and scans for misconfigurations.
  - Tools: Checkov, OPA (Open Policy Agent), terraform-compliance.
- **Cost Estimation**
  - Predicts infrastructure costs for every change.
  - Tool: Infracost.

***

## Testing Strategy

1. **Automate Static Analysis** – Run `terraform validate`, TFLint, and Checkov in CI/CD to prevent errors and enforce standards.
2. **Write Module Unit Tests** – Use the Terraform test framework to define scenarios and assertions for each module.
3. **Run Integration Tests** – Leverage Terratest or Kitchen-Terraform to create/destroy test environments, validate complex behaviors, and clean up all resources.
4. **Enforce Security & Compliance** – Integrate policy-as-code solutions and compliance tools in the pipeline.
5. **Estimate Cost Per Change** – Integrate Infracost or similar tooling for every pull request.
6. **Use Isolated Environments** – Always run tests in cloud accounts/projects dedicated to testing.
7. **Automate Clean-Up** – Ensure that all test environments are destroyed after test execution.
8. **Monitor and Refine** – Review results periodically to optimize coverage and reduce false positives.

***

## Cost-Saving Practices

- Automate environment creation and clean-up for every test run.[3]
- Use lowest-cost cloud resources and ephemeral (short-lived) environments.[10][11]
- Schedule test runs only during working hours; shut down overnight/weekends.[12]
- Tag test resources for easy monitoring and deletion.[13]
- Enforce quotas and cleanup of storage-heavy resources (e.g. S3/Blob lifecycle policies).
- Run smaller, faster tests first; use fail-fast to reduce wasted resource usage.[3]

***

## Pipeline Stages & Exit Criteria

| Stage              | Scope                     | Exit Criteria                                               |
|--------------------|--------------------------|-------------------------------------------------------------|
| Static Analysis    | All code                  | No failed linting, formatting, or security checks           |
| Unit/Contract Test | Single module/resource    | All assertions and conditions pass, zero failures           |
| Integration Test   | Isolated cloud resources  | Expected behavior verified, all resources cleaned up        |
| E2E Test           | Full infra & user flows   | System/functional assertions pass, no infrastructure drift  |
| Manual Approval    | Plan review               | Explicit approval before production deployment              |
| Cost Estimation    | All planned changes       | Costs within approved thresholds                            |

***

## Tooling Summary

| Layer           | Recommended Tool         | Maturity/Simplicity  |
|-----------------|-------------------------|----------------------|
| Static Analysis | Terraform CLI, TFLint   | Native, easy         |
| Security        | Checkov, OPA            | Mature, simple to add|
| Unit Testing    | Terraform test framework| Native, HCL-based    |
| Integration     | Terratest, Kitchen-TF   | Mature, needs Go/Ruby|
| Cost Review     | Infracost               | Easy, pipeline-ready |

***

## References
- [Best practices for testing | Terraform](https://docs.cloud.google.com/docs/terraform/best-practices/testing)[3]
- [Terraform CI/CD and testing on AWS](https://aws.amazon.com/blogs/devops/terraform-ci-cd-and-testing-on-aws-with-the-new-terraform-test-framework/)[5]
- [How to Test Terraform Code - Spacelift](https://spacelift.io/blog/terraform-test)[7]
- [Testing Terraform code - Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/azurerm/best-practices-testing-overview)[6]

***

This document serves as a practical reference for selecting and implementing Terraform testing options in production environments.[5][6][7][3]

[1](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
[2](https://developer.hashicorp.com/terraform/language/tests)
[3](https://docs.cloud.google.com/docs/terraform/best-practices/testing)
[4](https://github.com/christosgalano/terraform-testing-example)
[5](https://aws.amazon.com/blogs/devops/terraform-ci-cd-and-testing-on-aws-with-the-new-terraform-test-framework/)
[6](https://learn.microsoft.com/en-us/azure/developer/terraform/azurerm/best-practices-testing-overview)
[7](https://spacelift.io/blog/terraform-test)
[8](https://microsoft.github.io/code-with-engineering-playbook/CI-CD/recipes/terraform/terraform-structure-guidelines/)
[9](https://thomasthornton.cloud/2025/01/08/getting-started-using-terraform-tests-with-azure-example/)
[10](https://controlmonkey.io/blog/terraform-aws-cost-optimization-playbook/)
[11](https://www.enov8.com/blog/controlling-costs-and-scaling-down-test-environments/)
[12](https://www.flexential.com/resources/blog/cloud-cost-optimization)
[13](https://spacelift.io/blog/cloud-cost-optimization)