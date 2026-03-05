# =============================================================================
# Backend Configuration - dotai MCP Server (Production)
# =============================================================================

terraform {
  cloud {
    organization = "Datafaced"

    workspaces {
      name = "production-applications-dotai-mcp"
    }
  }
}
