#!/bin/bash

#!/bin/bash
#
# Azure Hub-Spoke VNet Configuration Script
# 
# This script configures existing Azure resources for hub-spoke connectivity:
# - Creates VNet peering between existing hub and spoke VNets
# - Links existing private DNS zones to spoke VNet
# - Updates existing VPN Gateway Point-to-Site routes
#
# Prerequisites:
# - Azure CLI installed and authenticated
# - Hub VNet must already exist
# - Spoke VNet must already exist  
# - VPN Gateway must already exist (if route updates needed)
# - Private DNS zones must already exist in hub resource group
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
}

print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

# Function to safely exit
safe_exit() {
    local exit_code=${1:-0}
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        # Script is being sourced, return instead of exit
        return $exit_code
    else
        exit $exit_code
    fi
}

# Function to display usage
show_usage() {
    echo "Azure Hub-Spoke VNet Configuration Script"
    echo ""
    echo "USAGE:"
    echo "  $0 -e ENVIRONMENT -s SPOKE_VNET_ID [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  -e ENVIRONMENT        Environment name (dev, prod, etc.)"
    echo "  -s SPOKE_VNET_ID      Full resource ID of the spoke VNet to peer"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  -g HUB_RESOURCE_GROUP Resource group containing hub resources"
    echo "                        Default: auto-{environment}-hub-network-rg"
    echo "  -n SPOKE_NAME         Friendly name for the spoke (used in peering names)"
    echo "                        Default: extracted from VNet ID"
    echo "  -h                    Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  # Configure existing resources for hub-spoke connectivity"
    echo "  $0 -e dev -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet'"
    echo ""
    echo "  # Custom spoke name and hub resource group"
    echo "  $0 -e prod -s '/subscriptions/12345/resourceGroups/app-rg/providers/Microsoft.Network/virtualNetworks/app-vnet' -n 'application' -g 'custom-hub-rg'"
    echo ""
    echo "NOTES:"
    echo "  • VPN Gateway routes are automatically configured via BGP and gateway transit"
    echo "  • No manual route configuration needed for modern Azure VPN deployments"
    echo ""
    echo "EXPECTED RESOURCE NAMING:"
    echo "  Hub VNet: auto-hub-{environment}-vnet"
    echo "  Hub Resource Group: auto-{environment}-hub-network-rg"
    echo ""
}

# Function to validate Azure CLI login
check_azure_login() {
    print_step "Checking Azure CLI authentication..."
    
    if ! az account show >/dev/null 2>&1; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first."
        safe_exit 1
    fi
    
    local subscription_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    print_success "Authenticated to Azure subscription: $subscription_name ($subscription_id)"
}

# Function to extract spoke VNet name from resource ID
extract_spoke_name() {
    local spoke_vnet_id="$1"
    echo "$spoke_vnet_id" | sed 's|.*/virtualNetworks/||'
}

# Function to extract resource group from resource ID
extract_resource_group() {
    local resource_id="$1"
    echo "$resource_id" | sed 's|.*/resourceGroups/\([^/]*\)/.*|\1|'
}

# Function to validate all required resources exist
validate_resources() {
    local hub_rg="$1"
    local hub_vnet="$2"
    local spoke_vnet_id="$3"
    local environment="$4"
    
    print_step "Validating all required resources exist..."
    
    # Validate hub VNet exists
    local hub_vnet_id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${hub_rg}/providers/Microsoft.Network/virtualNetworks/${hub_vnet}"
    if ! az network vnet show --ids "$hub_vnet_id" >/dev/null 2>&1; then
        print_error "Hub VNet not found: $hub_vnet_id"
        print_error "Please ensure the hub network infrastructure is deployed first."
        safe_exit 1
    fi
    print_success "✓ Hub VNet exists: $hub_vnet"
    
    # Validate spoke VNet exists
    local spoke_vnet_name=$(extract_spoke_name "$spoke_vnet_id")
    if ! az network vnet show --ids "$spoke_vnet_id" >/dev/null 2>&1; then
        print_error "Spoke VNet not found: $spoke_vnet_id"
        print_error "Please ensure the spoke VNet is created first."
        safe_exit 1
    fi
    print_success "✓ Spoke VNet exists: $spoke_vnet_name"
    
    # Validate VPN Gateway exists (optional - warn if not found)
    local vpn_gateway="auto-hub-${environment}-vpngw"
    if ! az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" >/dev/null 2>&1; then
        print_warning "⚠ VPN Gateway not found: $vpn_gateway"
        print_warning "  VPN route updates will be skipped."
    else
        print_success "✓ VPN Gateway exists: $vpn_gateway"
    fi
    
    # Validate private DNS zones exist (warn if none found)
    local dns_zones=$(az network private-dns zone list --resource-group "$hub_rg" --query "[].name" -o tsv 2>/dev/null)
    if [[ -z "$dns_zones" ]]; then
        print_warning "⚠ No private DNS zones found in resource group: $hub_rg"
        print_warning "  DNS zone linking will be skipped."
    else
        local zone_count=$(echo "$dns_zones" | wc -l | tr -d ' ')
        print_success "✓ Found $zone_count private DNS zones for linking"
    fi
    
    print_success "Resource validation completed!"
}

# Function to find existing peering to remote VNet
find_existing_peering() {
    local resource_group="$1"
    local vnet_name="$2"
    local remote_vnet_id="$3"
    
    # Get all peerings and find one that references the target remote VNet
    az network vnet peering list \
        --resource-group "$resource_group" \
        --vnet-name "$vnet_name" \
        --query "[?remoteVirtualNetwork.id=='$remote_vnet_id'].name" \
        -o tsv 2>/dev/null | head -n1
}

# Function to check if peering is in a healthy state
check_peering_state() {
    local resource_group="$1"
    local vnet_name="$2"
    local peering_name="$3"
    
    # Get the peering state
    az network vnet peering show \
        --resource-group "$resource_group" \
        --vnet-name "$vnet_name" \
        --name "$peering_name" \
        --query "peeringState" \
        -o tsv 2>/dev/null
}

# Function to configure VNet peering
configure_peering() {
    local hub_rg="$1"
    local hub_vnet="$2"
    local spoke_vnet_id="$3"
    local spoke_name="$4"
    
    local hub_to_spoke_name="hub-to-${spoke_name}"
    local spoke_to_hub_name="${spoke_name}-to-hub"
    local spoke_rg=$(extract_resource_group "$spoke_vnet_id")
    local spoke_vnet=$(extract_spoke_name "$spoke_vnet_id")
    local hub_vnet_id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${hub_rg}/providers/Microsoft.Network/virtualNetworks/${hub_vnet}"
    
    print_step "Configuring VNet peering between existing hub and spoke VNets..."
    
    # Check for existing peerings in both directions
    local existing_hub_peering=$(find_existing_peering "$hub_rg" "$hub_vnet" "$spoke_vnet_id")
    local existing_spoke_peering=$(find_existing_peering "$spoke_rg" "$spoke_vnet" "$hub_vnet_id")
    
    # Check peering states
    local hub_peering_state=""
    local spoke_peering_state=""
    
    if [[ -n "$existing_hub_peering" ]]; then
        hub_peering_state=$(check_peering_state "$hub_rg" "$hub_vnet" "$existing_hub_peering")
    fi
    
    if [[ -n "$existing_spoke_peering" ]]; then
        spoke_peering_state=$(check_peering_state "$spoke_rg" "$spoke_vnet" "$existing_spoke_peering")
    fi
    
    # If both directions exist and are in good state, we're done
    if [[ -n "$existing_hub_peering" ]] && [[ -n "$existing_spoke_peering" ]] && \
       [[ "$hub_peering_state" == "Connected" ]] && [[ "$spoke_peering_state" == "Connected" ]]; then
        print_success "✓ Bidirectional peering already exists and is connected:"
        print_info "  Hub→Spoke: $existing_hub_peering ($hub_peering_state)"
        print_info "  Spoke→Hub: $existing_spoke_peering ($spoke_peering_state)"
        print_info "Skipping peering configuration - already configured."
        return 0
    fi
    
    # Handle disconnected peerings - need to delete and recreate
    if [[ -n "$existing_hub_peering" ]] && [[ "$hub_peering_state" == "Disconnected" ]]; then
        print_warning "Hub peering '$existing_hub_peering' is disconnected. Removing it for recreation..."
        az network vnet peering delete --resource-group "$hub_rg" --vnet-name "$hub_vnet" --name "$existing_hub_peering" >/dev/null
        existing_hub_peering=""
    fi
    
    if [[ -n "$existing_spoke_peering" ]] && [[ "$spoke_peering_state" == "Disconnected" ]]; then
        print_warning "Spoke peering '$existing_spoke_peering' is disconnected. Removing it for recreation..."
        az network vnet peering delete --resource-group "$spoke_rg" --vnet-name "$spoke_vnet" --name "$existing_spoke_peering" >/dev/null
        existing_spoke_peering=""
    fi
    
    # Create hub-to-spoke peering only if it doesn't exist
    if [[ -z "$existing_hub_peering" ]]; then
        print_step "Creating hub-to-spoke peering: $hub_to_spoke_name"
        if az network vnet peering create \
            --resource-group "$hub_rg" \
            --name "$hub_to_spoke_name" \
            --vnet-name "$hub_vnet" \
            --remote-vnet "$spoke_vnet_id" \
            --allow-vnet-access \
            --allow-forwarded-traffic \
            --allow-gateway-transit >/dev/null 2>&1; then
            print_success "✓ Created hub-to-spoke peering: $hub_to_spoke_name"
        else
            print_error "Failed to create hub-to-spoke peering"
            safe_exit 1
        fi
    else
        # Get current state for display
        hub_peering_state=$(check_peering_state "$hub_rg" "$hub_vnet" "$existing_hub_peering")
        print_info "✓ Hub-to-spoke peering already exists: $existing_hub_peering ($hub_peering_state)"
    fi
    
    # Create spoke-to-hub peering only if it doesn't exist
    if [[ -z "$existing_spoke_peering" ]]; then
        print_step "Creating spoke-to-hub peering: $spoke_to_hub_name"
        if az network vnet peering create \
            --resource-group "$spoke_rg" \
            --name "$spoke_to_hub_name" \
            --vnet-name "$spoke_vnet" \
            --remote-vnet "$hub_vnet_id" \
            --allow-vnet-access \
            --allow-forwarded-traffic \
            --use-remote-gateways >/dev/null 2>&1; then
            print_success "✓ Created spoke-to-hub peering: $spoke_to_hub_name"
        else
            print_error "Failed to create spoke-to-hub peering"
            safe_exit 1
        fi
    else
        # Get current state for display
        spoke_peering_state=$(check_peering_state "$spoke_rg" "$spoke_vnet" "$existing_spoke_peering")
        print_info "✓ Spoke-to-hub peering already exists: $existing_spoke_peering ($spoke_peering_state)"
    fi
    
    print_success "VNet peering configuration completed successfully!"
}

# Function to get private DNS zones from hub resource group
get_private_dns_zones() {
    local hub_rg="$1"
    
    # Get DNS zones without printing status (to avoid mixing output)
    local dns_zones=$(az network private-dns zone list --resource-group "$hub_rg" --query "[].name" -o tsv 2>/dev/null)
    
    if [[ -z "$dns_zones" ]]; then
        return 1
    fi
    
    echo "$dns_zones"
}

# Function to check if VNet is already linked to DNS zone
check_vnet_dns_link() {
    local hub_rg="$1"
    local zone_name="$2"
    local spoke_vnet_id="$3"
    
    # Get all VNet links for this DNS zone and check if any reference our spoke VNet
    az network private-dns link vnet list \
        --resource-group "$hub_rg" \
        --zone-name "$zone_name" \
        --query "[?virtualNetwork.id=='$spoke_vnet_id'].name" \
        -o tsv 2>/dev/null | head -n1
}

# Function to link DNS zones to both hub and spoke VNets
link_dns_zones() {
    local hub_rg="$1"
    local hub_vnet="$2"
    local spoke_vnet_id="$3"
    local spoke_name="$4"
    local environment="$5"
    
    print_step "Linking private DNS zones to hub and spoke VNets..."
    
    # Get hub VNet ID
    local hub_vnet_id=$(az network vnet show --resource-group "$hub_rg" --name "$hub_vnet" --query "id" -o tsv 2>/dev/null)
    if [[ -z "$hub_vnet_id" ]]; then
        print_warning "Could not get hub VNet ID. Skipping hub DNS zone linking."
        hub_vnet_id=""
    fi
    
    # Get all private DNS zones in hub resource group
    print_step "Finding private DNS zones in hub resource group..."
    local dns_zones
    if ! dns_zones=$(get_private_dns_zones "$hub_rg"); then
        print_warning "Skipping DNS zone linking - no zones found"
        return 0
    fi
    
    local zone_count=$(echo "$dns_zones" | wc -l | tr -d ' ')
    print_success "Found $zone_count DNS zones to link"
    
    # Link each DNS zone to both hub and spoke VNets
    while IFS= read -r zone_name; do
        [[ -z "$zone_name" ]] && continue
        
        print_step "Linking DNS zone '$zone_name'..."
        
        # Link to spoke VNet
        local spoke_link_name="${spoke_name}-link"
        local existing_spoke_link=$(check_vnet_dns_link "$hub_rg" "$zone_name" "$spoke_vnet_id")
        
        if [[ -n "$existing_spoke_link" ]]; then
            print_info "  ✓ Spoke VNet already linked via '$existing_spoke_link'"
        else
            if az network private-dns link vnet create \
                --resource-group "$hub_rg" \
                --zone-name "$zone_name" \
                --name "$spoke_link_name" \
                --virtual-network "$spoke_vnet_id" \
                --registration-enabled false >/dev/null 2>&1; then
                print_success "  ✓ Linked to spoke VNet"
            else
                print_warning "  Failed to link to spoke VNet (may already be linked)"
            fi
        fi
        
        # Link to hub VNet (if we got the hub VNet ID)
        if [[ -n "$hub_vnet_id" ]]; then
            local hub_link_name="hub-${environment}-link"
            local existing_hub_link=$(check_vnet_dns_link "$hub_rg" "$zone_name" "$hub_vnet_id")
            
            if [[ -n "$existing_hub_link" ]]; then
                print_info "  ✓ Hub VNet already linked via '$existing_hub_link'"
            else
                if az network private-dns link vnet create \
                    --resource-group "$hub_rg" \
                    --zone-name "$zone_name" \
                    --name "$hub_link_name" \
                    --virtual-network "$hub_vnet_id" \
                    --registration-enabled false >/dev/null 2>&1; then
                    print_success "  ✓ Linked to hub VNet"
                else
                    print_warning "  Failed to link to hub VNet (may already be linked)"
                fi
            fi
        fi
        
    done <<< "$dns_zones"
    
    print_success "DNS zone linking completed!"
}

# Main function
main() {
    local environment=""
    local spoke_vnet_id=""
    local hub_resource_group=""
    local spoke_name=""
    
    # Parse command line arguments
    while getopts "e:s:g:n:h" opt; do
        case $opt in
            e) environment="$OPTARG" ;;
            s) spoke_vnet_id="$OPTARG" ;;
            g) hub_resource_group="$OPTARG" ;;
            n) spoke_name="$OPTARG" ;;
            h) show_usage; safe_exit 0 ;;
            *) show_usage; safe_exit 1 ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$environment" || -z "$spoke_vnet_id" ]]; then
        print_error "Missing required parameters"
        show_usage
        safe_exit 1
    fi
    
    # Set default values
    [[ -z "$hub_resource_group" ]] && hub_resource_group="auto-${environment}-hub-network-rg"
    [[ -z "$spoke_name" ]] && spoke_name=$(extract_spoke_name "$spoke_vnet_id")
    
    # Define resource names
    local hub_vnet="auto-hub-${environment}-vnet"
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Azure Hub-Spoke VNet Configuration Script"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Environment: $environment"
    echo "Hub Resource Group: $hub_resource_group"
    echo "Hub VNet: $hub_vnet"
    echo "Spoke VNet ID: $spoke_vnet_id"
    echo "Spoke Name: $spoke_name"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Check Azure authentication
    check_azure_login
    
    # Validate all required resources exist
    validate_resources "$hub_resource_group" "$hub_vnet" "$spoke_vnet_id" "$environment"
    
    # Configure peering
    configure_peering "$hub_resource_group" "$hub_vnet" "$spoke_vnet_id" "$spoke_name"
    
    # Link DNS zones to both hub and spoke VNets
    link_dns_zones "$hub_resource_group" "$hub_vnet" "$spoke_vnet_id" "$spoke_name" "$environment"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    print_success "Hub-Spoke configuration completed successfully!"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    print_info "Configuration Summary:"
    echo "• VNet peering configured between existing hub and spoke VNets"
    echo "• Gateway transit enabled for VPN access to spoke resources"
    echo "• Private DNS zones linked to both hub and spoke VNets for name resolution"
    echo "• VPN Gateway automatically advertises spoke routes via BGP and gateway transit"
    echo ""
    print_info "Next Steps:"
    echo "1. Resources in spoke VNet can now access hub resources"
    echo "2. VPN clients will automatically receive routes to spoke VNet via BGP"
    echo "3. Private endpoints in spoke VNet will resolve through linked DNS zones"
    echo "4. Test connectivity from VPN clients to spoke resources"
    echo ""
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi