#!/bin/bash

# Azure VPN Configuration Extraction Script
# This script extracts VPN client configuration from an Azure VPN Gateway
# and configures it with DNS resolver settings

#set -e  # Exit on error

# Function to safely exit script (handles both direct execution and sourcing)
safe_exit() {
    local exit_code=${1:-0}
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        # Script is being executed directly
        exit $exit_code
    else
        # Script is being sourced
        return $exit_code
    fi
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=""
RESOURCE_GROUP_NAME=""
VPN_GATEWAY_NAME=""
DNS_RESOLVER_NAME=""
VNET_NAME=""
OUTPUT_DIR="./output"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
usage() {
    echo "Usage: $0 -e ENVIRONMENT [-g RESOURCE_GROUP] [-o OUTPUT_DIR]"
    echo ""
    echo "Options:"
    echo "  -e ENVIRONMENT      Environment name (dev, prod, etc.)"
    echo "  -g RESOURCE_GROUP   Resource group name (optional, auto-generated if not provided)"
    echo "  -o OUTPUT_DIR       Output directory for VPN configuration files (default: current directory)"
    echo "  -h                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod -g my-custom-rg -o ./vpn-configs"
    safe_exit 1
}

# Parse command line arguments
while getopts "e:g:o:h" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        g)
            RESOURCE_GROUP_NAME="$OPTARG"
            ;;
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment is required. Use -e flag."
    usage
fi

# Set default resource names if not provided
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    RESOURCE_GROUP_NAME="auto-${ENVIRONMENT}-hub-network-rg"
fi

VPN_GATEWAY_NAME="auto-hub-${ENVIRONMENT}-vpngw"
DNS_RESOLVER_NAME="auto-hub-${ENVIRONMENT}-dnspr"
VNET_NAME="auto-hub-${ENVIRONMENT}-vnet"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

print_info "Azure VPN Configuration Extraction"
echo "=================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "VPN Gateway: $VPN_GATEWAY_NAME"
echo "DNS Resolver: $DNS_RESOLVER_NAME"
echo "Virtual Network: $VNET_NAME"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    safe_exit 1
fi

print_info "Looking up existing resources..."

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP_NAME" > /dev/null 2>&1; then
    print_error "Resource group '$RESOURCE_GROUP_NAME' not found"
    print_info "Please deploy the infrastructure first or check the resource group name"
    safe_exit 1
fi

print_success "Found resource group: $RESOURCE_GROUP_NAME"

# Get VPN Gateway details
print_info "Getting VPN Gateway details..."
VPN_GATEWAY_INFO=$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_NAME" \
    --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "VPN Gateway '$VPN_GATEWAY_NAME' not found in '$RESOURCE_GROUP_NAME'"
    safe_exit 1
fi

VPN_GATEWAY_PUBLIC_IP_ID=$(echo "$VPN_GATEWAY_INFO" | jq -r '.ipConfigurations[0].publicIPAddress.id')
VPN_GATEWAY_PUBLIC_IP=$(az network public-ip show --ids "$VPN_GATEWAY_PUBLIC_IP_ID" --query ipAddress --output tsv)

print_success "Found VPN Gateway with public IP: $VPN_GATEWAY_PUBLIC_IP"

# Get DNS Resolver inbound endpoint IP
print_info "Getting DNS Resolver details..."
az config set extension.dynamic_install_allow_preview=true
DNS_RESOLVER_INBOUND_ENDPOINTS=$(az dns-resolver inbound-endpoint list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --dns-resolver-name "$DNS_RESOLVER_NAME" \
    --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "DNS Resolver '$DNS_RESOLVER_NAME' not found in '$RESOURCE_GROUP_NAME'"
    safe_exit 1
fi

DNS_SERVER_IP=$(echo "$DNS_RESOLVER_INBOUND_ENDPOINTS" | jq -r '.[0].ipConfigurations[0].privateIpAddress')

if [ "$DNS_SERVER_IP" == "null" ] || [ -z "$DNS_SERVER_IP" ]; then
    print_error "Could not extract DNS resolver inbound endpoint IP"
    safe_exit 1
fi

print_success "Found DNS resolver inbound endpoint IP: $DNS_SERVER_IP"

# Generate VPN client configuration
print_info "Generating VPN client configuration..."
az network vnet-gateway vpn-client generate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_NAME" \
    --authentication-method EAPTLS \
    --output json > vpn-client-config.json

# Parse the response
if jq -e '.error' vpn-client-config.json > /dev/null 2>&1; then
    print_error "Error in VPN client configuration generation:"
    jq -r '.error.message' vpn-client-config.json
    VPN_CONFIG_URL=""
elif jq -e '.' vpn-client-config.json | grep -q '"https://'; then
    VPN_CONFIG_URL=$(jq -r '.' vpn-client-config.json)
elif jq -e '.vpnClientConfiguration.vpnClientUrl' vpn-client-config.json > /dev/null 2>&1; then
    VPN_CONFIG_URL=$(jq -r '.vpnClientConfiguration.vpnClientUrl' vpn-client-config.json)
else
    print_warning "Unable to extract VPN configuration URL from response"
    VPN_CONFIG_URL=""
fi

# Download and extract VPN client configuration if URL is available
VPN_CONFIG_AVAILABLE=false

if [ -n "$VPN_CONFIG_URL" ] && [ "$VPN_CONFIG_URL" != "null" ]; then
    print_info "Downloading VPN client configuration package..."
    if curl -L -o vpn-client-package.zip "$VPN_CONFIG_URL"; then
        print_info "Extracting VPN client package..."
        # Try to extract with different options for compatibility
        if unzip -o -j vpn-client-package.zip 2>/dev/null || unzip -o vpn-client-package.zip 2>/dev/null; then
            print_success "VPN client package extracted successfully"
        else
            print_warning "Unzip had warnings but may have extracted files"
        fi
        
        # Process both Azure VPN Client and OpenVPN configurations
        AZUREVPN_XML_FILE=$(find . -name "azurevpnconfig.xml" -type f | head -1)
        OVPN_FILE=$(find . -name "*.ovpn" -type f | head -1)
        
        # Handle Azure VPN Client configuration
        if [ -n "$AZUREVPN_XML_FILE" ]; then
            print_info "Processing Azure VPN Client configuration (azurevpnconfig.xml)..."
            cp "$AZUREVPN_XML_FILE" "azurevpnconfig.xml"
            # Add DNS settings to Azure VPN Client config with proper XML structure
            sed -i.bak "s|<clientconfig i:nil=\"true\" />|<clientconfig>\n    <dnsservers>\n      <dnsserver>$DNS_SERVER_IP</dnsserver>\n    </dnsservers>\n  </clientconfig>|" "azurevpnconfig.xml"
            VPN_CONFIG_AVAILABLE=true
        fi
        
        # Handle OpenVPN configuration
        if [ -n "$OVPN_FILE" ]; then
            print_info "Processing OpenVPN configuration..."
            cp "$OVPN_FILE" "azure-hub-vpn-${ENVIRONMENT}.ovpn"
            # Add DNS configuration to the OVPN file
            {
                echo ""
                echo "# DNS Configuration - Azure Private DNS Resolver"
                echo "dhcp-option DNS $DNS_SERVER_IP"
                echo "dhcp-option DOMAIN internal.cloudapp.net"
            } >> "azure-hub-vpn-${ENVIRONMENT}.ovpn"
            VPN_CONFIG_AVAILABLE=true
        fi
    else
        print_error "Failed to download VPN client package"
    fi
fi

# If no configuration files were found, create manual configuration instructions
if [ "$VPN_CONFIG_AVAILABLE" = false ]; then
    print_warning "No VPN configuration files found - creating manual setup instructions"
    
    # Create a basic Azure VPN Client configuration template (azurevpnconfig.xml)
    cat > "azurevpnconfig.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<AzureProfile xmlns="http://schemas.microsoft.com/azure/vpnclient/profile/2019/07/01">
  <clientconfig>
    <name>Azure Hub VPN - ${ENVIRONMENT}</name>
    <vpnserver>$VPN_GATEWAY_PUBLIC_IP</vpnserver>
    <dnsservers>
      <dnsserver>$DNS_SERVER_IP</dnsserver>
    </dnsservers>
    <trustednetworkdetection />
    <authentication>
      <authenticationtype>AAD</authenticationtype>
    </authentication>
  </clientconfig>
</AzureProfile>
EOF
    VPN_CONFIG_AVAILABLE=true
fi

# Create comprehensive VPN configuration documentation
print_info "Creating VPN configuration documentation..."
cat > "vpn-configuration.txt" <<EOF
========================================
Azure Hub Network VPN Configuration
========================================
Environment: $ENVIRONMENT
Generated: $(date)

VPN Gateway Details:
-------------------
Gateway Name: $VPN_GATEWAY_NAME
Gateway Public IP: $VPN_GATEWAY_PUBLIC_IP
Resource Group: $RESOURCE_GROUP_NAME
Virtual Network: $VNET_NAME

DNS Resolver Details:
--------------------
Inbound Endpoint IP: $DNS_SERVER_IP

VPN Client Configuration:
------------------------
Available configuration files:

1. Azure VPN Client (Recommended):
   - File: azurevpnconfig.xml
   - Download Azure VPN Client from Microsoft Store/App Store
   - Better Azure AD integration and user experience

2. OpenVPN Client (Alternative):
   - File: azure-hub-vpn-${ENVIRONMENT}.ovpn (if available)
   - Use with OpenVPN Connect or other OpenVPN clients
   - More universal compatibility

Both configurations include:
- DNS Server: $DNS_SERVER_IP (configured in <dnsservers><dnsserver> section)
- Domain suffix: internal.cloudapp.net

Installation Instructions:
-------------------------

For Azure VPN Client:
1. Install Azure VPN Client from Microsoft Store (Windows) or App Store (macOS/iOS)
2. Import the azurevpnconfig.xml file
3. Connect using your Azure AD credentials

For OpenVPN Client:
1. Install OpenVPN Connect or compatible client
2. Import the azure-hub-vpn-${ENVIRONMENT}.ovpn file (if available)
3. Connect using your Azure AD credentials

Testing DNS Resolution:
----------------------
After connecting to VPN, test DNS resolution:
- nslookup internal.cloudapp.net $DNS_SERVER_IP
- nslookup <your-private-resource-name>.internal.cloudapp.net

========================================
EOF

# Clean up temporary files
rm -f vpn-client-config.json vpn-client-package.zip *.bak 2>/dev/null || true

print_success "VPN configuration extraction completed!"
echo ""
echo "Generated files:"
echo "- vpn-configuration.txt (instructions)"
echo "- azurevpnconfig.xml (Azure VPN Client profile)"
if [ -f "azure-hub-vpn-${ENVIRONMENT}.ovpn" ]; then
    echo "- azure-hub-vpn-${ENVIRONMENT}.ovpn (OpenVPN profile)"
fi
echo ""
print_info "Files are available in: $(pwd)"