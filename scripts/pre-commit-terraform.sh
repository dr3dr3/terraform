#!/usr/bin/env bash
# Pre-commit hook for Terraform validation
# Install: cp scripts/pre-commit-terraform.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if any terraform files are staged
TERRAFORM_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^terraform/.*\.tf$' || true)

if [ -z "$TERRAFORM_FILES" ]; then
    echo -e "${GREEN}No Terraform files staged, skipping Terraform checks${NC}"
    exit 0
fi

echo -e "${YELLOW}Running Terraform pre-commit checks...${NC}"

# Get unique directories with changed Terraform files
TERRAFORM_DIRS=$(echo "$TERRAFORM_FILES" | xargs -I {} dirname {} | sort -u)

# Track if any check fails
FAILED=0

# 1. Terraform Format Check
echo -e "\n${YELLOW}[1/4] Checking terraform fmt...${NC}"
if ! terraform fmt -check -recursive terraform/; then
    echo -e "${RED}✗ Terraform formatting check failed${NC}"
    echo -e "Run: ${YELLOW}terraform fmt -recursive terraform/${NC}"
    FAILED=1
else
    echo -e "${GREEN}✓ Terraform formatting OK${NC}"
fi

# 2. Terraform Validate (per directory)
echo -e "\n${YELLOW}[2/4] Running terraform validate...${NC}"
for dir in $TERRAFORM_DIRS; do
    if [ -f "$dir/main.tf" ] || [ -f "$dir/versions.tf" ]; then
        echo "  Validating: $dir"
        pushd "$dir" > /dev/null
        if ! terraform validate > /dev/null 2>&1; then
            echo -e "${RED}✗ Validation failed in $dir${NC}"
            terraform validate
            FAILED=1
        fi
        popd > /dev/null
    fi
done
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform validation OK${NC}"
fi

# 3. TFLint (if installed)
echo -e "\n${YELLOW}[3/4] Running tflint...${NC}"
if command -v tflint &> /dev/null; then
    for dir in $TERRAFORM_DIRS; do
        if [ -f "$dir/main.tf" ] || [ -f "$dir/versions.tf" ]; then
            echo "  Linting: $dir"
            pushd "$dir" > /dev/null
            if ! tflint --config="$OLDPWD/.tflint.hcl" 2>/dev/null; then
                echo -e "${RED}✗ TFLint found issues in $dir${NC}"
                FAILED=1
            fi
            popd > /dev/null
        fi
    done
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ TFLint OK${NC}"
    fi
else
    echo -e "${YELLOW}⚠ tflint not installed, skipping${NC}"
fi

# 4. Checkov (if installed)
echo -e "\n${YELLOW}[4/4] Running checkov...${NC}"
if command -v checkov &> /dev/null; then
    if ! checkov -d terraform/ --quiet --compact 2>/dev/null; then
        echo -e "${YELLOW}⚠ Checkov found security issues (review recommended)${NC}"
        # Not failing on checkov by default - uncomment to enforce
        # FAILED=1
    else
        echo -e "${GREEN}✓ Checkov OK${NC}"
    fi
else
    echo -e "${YELLOW}⚠ checkov not installed, skipping${NC}"
fi

echo ""
if [ $FAILED -ne 0 ]; then
    echo -e "${RED}Pre-commit checks failed. Please fix the issues above.${NC}"
    exit 1
fi

echo -e "${GREEN}All Terraform pre-commit checks passed!${NC}"
exit 0
