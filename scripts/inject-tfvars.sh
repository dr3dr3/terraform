#!/usr/bin/env bash

# Script to inject 1Password secrets into Terraform tfvars files
# Uses 1Password CLI to replace secret references with actual values
# 
# Usage:
#   ./scripts/inject-tfvars.sh              # Inject all tfvars.example files
#   ./scripts/inject-tfvars.sh --dry-run    # Show what would be injected without creating files
#   ./scripts/inject-tfvars.sh --verify     # Verify 1Password CLI is working

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env file if it exists and OP_SERVICE_ACCOUNT_TOKEN is not already set
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    # Export variables from .env file (only lines with = that aren't comments)
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DRY_RUN=false
VERIFY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Function to check if 1Password CLI is installed and authenticated
check_op_cli() {
    if ! command -v op &> /dev/null; then
        echo -e "${RED}Error: 1Password CLI (op) is not installed${NC}"
        echo "Install from: https://developer.1password.com/docs/cli/get-started/"
        exit 1
    fi

    # Check for service account token first (CI/CD and automation scenarios)
    if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
        # Verify service account works by trying to list vaults
        if op vault list --format=json &> /dev/null; then
            echo -e "${GREEN}✓ 1Password CLI authenticated via service account${NC}"
            return 0
        else
            echo -e "${RED}Error: OP_SERVICE_ACCOUNT_TOKEN is set but authentication failed${NC}"
            echo "Check that your service account token is valid and has access to the required vaults"
            exit 1
        fi
    fi

    # Fall back to interactive account check
    if ! op account list &> /dev/null; then
        echo -e "${RED}Error: Not signed in to 1Password${NC}"
        echo "Run: op signin"
        echo "Or set OP_SERVICE_ACCOUNT_TOKEN for automation"
        exit 1
    fi

    echo -e "${GREEN}✓ 1Password CLI is installed and authenticated${NC}"
}

# Function to verify 1Password secrets can be accessed
verify_secrets() {
    echo -e "${YELLOW}Verifying 1Password secret references...${NC}"
    
    local found_refs=false
    while IFS= read -r example_file; do
        if grep -q "op://" "$example_file" 2>/dev/null; then
            found_refs=true
            echo "Found secret references in: $example_file"
            grep "op://" "$example_file" | sed 's/^/  /'
        fi
    done < <(find terraform -name "terraform.tfvars.example" 2>/dev/null)
    
    if [ "$found_refs" = false ]; then
        echo -e "${YELLOW}No 1Password secret references found in any tfvars.example files${NC}"
        echo "Add references using format: op://vault-name/item-name/field-name"
    fi
}

# Function to inject secrets into a single file
inject_file() {
    local example_file=$1
    local tfvars_file="${example_file%.example}"
    
    echo -e "${YELLOW}Processing: $example_file${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "  Would create: $tfvars_file"
        if grep -q "op://" "$example_file" 2>/dev/null; then
            echo "  Contains 1Password references - would inject secrets"
        else
            echo "  No 1Password references found - would copy as-is"
        fi
    else
        # Check if file has 1Password references
        if grep -q "op://" "$example_file" 2>/dev/null; then
            # Try to inject secrets
            local inject_output
            if inject_output=$(op inject -i "$example_file" -o "$tfvars_file" 2>&1); then
                echo -e "${GREEN}  ✓ Created: $tfvars_file (secrets injected)${NC}"
            else
                echo -e "${RED}  ✗ Failed to inject secrets into: $tfvars_file${NC}"
                echo -e "${RED}    Error: $inject_output${NC}"
                return 1
            fi
        else
            # No secret references, just copy
            cp "$example_file" "$tfvars_file"
            echo -e "${GREEN}  ✓ Copied: $tfvars_file (no secrets to inject)${NC}"
        fi
    fi
}

# Main execution
main() {
    check_op_cli
    
    if [ "$VERIFY" = true ]; then
        verify_secrets
        exit 0
    fi
    
    echo -e "${YELLOW}Searching for terraform.tfvars.example files...${NC}"
    
    local file_count=0
    while IFS= read -r example_file; do
        inject_file "$example_file"
        file_count=$((file_count + 1))
    done < <(find terraform -name "terraform.tfvars.example" 2>/dev/null)
    
    if [ $file_count -eq 0 ]; then
        echo -e "${YELLOW}No terraform.tfvars.tpl files found${NC}"
        exit 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}Dry run complete. $file_count file(s) would be processed.${NC}"
        echo "Run without --dry-run to actually inject secrets."
    else
        echo -e "${GREEN}Successfully processed $file_count file(s)${NC}"
        echo -e "${YELLOW}Note: Generated .tfvars files are gitignored and should never be committed${NC}"
    fi
}

main
