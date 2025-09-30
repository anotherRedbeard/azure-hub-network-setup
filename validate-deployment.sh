#!/bin/bash

# Azure Hub Network Deployment Test Script
# This script validates the Bicep templates without deploying resources

set -e

echo "================================================"
echo "Azure Hub Network Deployment Validation Script"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Change to script directory
cd "$(dirname "$0")"

echo -e "${BLUE}Step 1: Validating Bicep templates...${NC}"
echo "-------------------------------------------"

# Validate main template
echo "Validating main.bicep..."
az bicep build --file infra/bicep/main.bicep
echo -e "${GREEN}✓ main.bicep is valid${NC}"
echo ""

# Validate VNet module
echo "Validating vnet.bicep module..."
az bicep build --file infra/bicep/modules/vnet.bicep
echo -e "${GREEN}✓ vnet.bicep is valid${NC}"
echo ""

# Validate VPN Gateway module
echo "Validating vpn-gateway.bicep module..."
az bicep build --file infra/bicep/modules/vpn-gateway.bicep
echo -e "${GREEN}✓ vpn-gateway.bicep is valid${NC}"
echo ""

# Validate DNS Resolver module
echo "Validating dns-resolver.bicep module..."
az bicep build --file infra/bicep/modules/dns-resolver.bicep
echo -e "${GREEN}✓ dns-resolver.bicep is valid${NC}"
echo ""

echo -e "${BLUE}Step 2: Checking parameter files...${NC}"
echo "-------------------------------------------"

# Check dev parameters
if [ -f "infra/parameters/dev.parameters.json" ]; then
    echo -e "${GREEN}✓ dev.parameters.json exists${NC}"
    cat infra/parameters/dev.parameters.json | jq '.parameters | keys'
else
    echo "✗ dev.parameters.json not found"
    exit 1
fi
echo ""

# Check prod parameters
if [ -f "infra/parameters/prod.parameters.json" ]; then
    echo -e "${GREEN}✓ prod.parameters.json exists${NC}"
    cat infra/parameters/prod.parameters.json | jq '.parameters | keys'
else
    echo "✗ prod.parameters.json not found"
    exit 1
fi
echo ""

echo -e "${BLUE}Step 3: Summary of deployment resources...${NC}"
echo "-------------------------------------------"
echo "The following resources will be deployed:"
echo "  • Resource Group"
echo "  • Virtual Network with 3 subnets:"
echo "    - GatewaySubnet (for VPN Gateway)"
echo "    - snet-dnsresolver-inbound (for DNS Resolver)"
echo "    - snet-dnsresolver-outbound (for DNS Resolver)"
echo "  • VPN Gateway with Public IP"
echo "  • Private DNS Resolver with Inbound and Outbound endpoints"
echo ""

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
