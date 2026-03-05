# dotai MCP Server — Production

Terraform workspace that provisions the AWS infrastructure for
[`dotai-mcp`](https://github.com/dr3dr3/dotai-mcp) in the **production** AWS account.

## Terraform Cloud Workspace

`production-applications-dotai-mcp`

## Resources

| Resource | Name | Purpose |
|----------|------|---------|
| ECR Repository | `dotai` | Container image registry for the Lambda function |
| ECR Lifecycle Policy | — | Retain last 5 images, expire older ones |
| Lambda Function | `dotai` | Runs the MCP server (container image, HTTP transport) |
| Lambda Function URL | — | Public HTTPS endpoint for MCP clients (auth via bearer token) |
| IAM Role | `dotai-lambda` | Least-privilege execution role for the Lambda |
| SSM SecureString | `/dotai/MCP_AUTH_TOKEN` | Auth token store (supports rotation without redeployment) |

## Required TFC Variables

| Variable | Type | Notes |
|----------|------|-------|
| `mcp_auth_token` | Sensitive | Bearer token for MCP client authentication |

## Outputs

| Output | Used by |
|--------|---------|
| `ecr_repository_url` | GitHub Actions deploy workflow (`AWS_ECR_REPOSITORY`) |
| `lambda_function_name` | GitHub Actions deploy workflow (`AWS_LAMBDA_FUNCTION_NAME`) |
| `function_url` | Claude Desktop / Claude Code MCP configuration |

## Connecting Claude Code

After `terraform apply`, register the server with Claude Code:

```bash
claude mcp add dotai \
  --transport http \
  --header "Authorization: Bearer <mcp_auth_token>" \
  <function_url>
```
