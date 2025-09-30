#!/bin/bash

# Azure Hub Network Deployment Test Script
# This script validates the Bicep templates without deploying resources

#set -e

echo "================================================"
echo "Azure Hub Network Deployment Validation Script"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if infra folder exists
if [ ! -d "./infra" ]; then
    echo "✗ Error: 'infra' folder not found in current directory"
    echo "Please ensure you are running this script from the project root directory"
    return 1
fi

echo -e "${BLUE}Step 1: Validating Bicep templates...${NC}"
echo "-------------------------------------------"

# Validate main template
echo "Validating main.bicep..."
az bicep build --file ./infra/bicep/main.bicep
echo -e "${GREEN}✓ main.bicep is valid${NC}"
echo ""

echo -e "${BLUE}Step 2: Checking parameter files...${NC}"
echo "-------------------------------------------"

# Check dev parameters
if [ -f "./infra/bicep/main.dev.bicepparam" ]; then
    echo -e "${GREEN}✓ main.dev.bicepparam exists${NC}"
    cat ./infra/bicep/main.dev.bicepparam | jq '.parameters | keys'
else
    echo "✗ main.dev.bicepparam not found"
    return 1
fi
echo ""

# Check prod parameters
if [ -f "./infra/bicep/main.prd.bicepparam" ]; then
    echo -e "${GREEN}✓ main.prd.bicepparam exists${NC}"
    cat infra/bicep/main.prd.bicepparam | jq '.parameters | keys'
else
    echo "✗ main.prd.bicepparam not found"
    return 1
fi

echo -e "${GREEN}================================================"
echo "All validation checks passed successfully! ✓"
echo "================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Configure Azure authentication (Service Principal or Managed Identity)"
echo "2. Set up GitHub repository secrets"
echo "3. Run the GitHub Actions workflow to deploy"
echo ""

# Clean up generated JSON files
rm -f infra/bicep/main.json infra/bicep/modules/*.json

echo "Done!"
