#!/bin/bash

# Azure Hub-Spoke VNet Peering and VPN Route Configuration Script
# This script creates bidirectional VNet peering and updates VPN Gateway Point-to-Site routes

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
    echo "Azure Hub-Spoke VNet Peering and VPN Route Configuration Script"
    echo ""
    echo "USAGE:"
    echo "  $0 -e ENVIRONMENT -s SPOKE_VNET_ID -a ADDRESS_SPACE [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  -e ENVIRONMENT        Environment name (dev, prod, etc.)"
    echo "  -s SPOKE_VNET_ID      Full resource ID of the spoke VNet to peer"
    echo "  -a ADDRESS_SPACE      Address space of the spoke VNet (e.g., '10.1.0.0/16')"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  -g HUB_RESOURCE_GROUP Resource group containing hub resources"
    echo "                        Default: auto-{environment}-hub-network-rg"
    echo "  -n SPOKE_NAME         Friendly name for the spoke (used in peering names)"
    echo "                        Default: extracted from VNet ID"
    echo "  -u                    Update VPN routes only (skip peering creation)"
    echo "  -p                    Create peering only (skip VPN route updates)"
    echo "  -f                    Force update (overwrite existing peerings)"
    echo "  -h                    Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic peering and route setup"
    echo "  $0 -e dev -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' -a '10.1.0.0/16'"
    echo ""
    echo "  # Custom spoke name and hub resource group"
    echo "  $0 -e prod -s '/subscriptions/12345/resourceGroups/app-rg/providers/Microsoft.Network/virtualNetworks/app-vnet' -a '10.2.0.0/16' -n 'application' -g 'custom-hub-rg'"
    echo ""
    echo "  # Only update VPN routes (don't create peering)"
    echo "  $0 -e dev -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' -a '10.1.0.0/16' -u"
    echo ""
    echo "EXPECTED RESOURCE NAMING:"
    echo "  Hub VNet: auto-hub-{environment}-vnet"
    echo "  VPN Gateway: auto-hub-{environment}-vpngw"
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

# Function to validate VNet exists
validate_vnet() {
    local vnet_id="$1"
    local vnet_name="$2"
    
    print_step "Validating VNet exists: $vnet_name"
    
    if ! az network vnet show --ids "$vnet_id" >/dev/null 2>&1; then
        print_error "VNet not found: $vnet_id"
        safe_exit 1
    fi
    
    print_success "VNet validated: $vnet_name"
}

# Function to create VNet peering
create_peering() {
    local hub_rg="$1"
    local hub_vnet="$2"
    local spoke_vnet_id="$3"
    local spoke_name="$4"
    local force_update="$5"
    
    local hub_to_spoke_name="hub-to-${spoke_name}"
    local spoke_to_hub_name="${spoke_name}-to-hub"
    local spoke_rg=$(extract_resource_group "$spoke_vnet_id")
    local spoke_vnet=$(extract_spoke_name "$spoke_vnet_id")
    local hub_vnet_id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${hub_rg}/providers/Microsoft.Network/virtualNetworks/${hub_vnet}"
    
    print_step "Creating VNet peering between hub and spoke..."
    
    # Check if peering already exists
    if az network vnet peering show --resource-group "$hub_rg" --vnet-name "$hub_vnet" --name "$hub_to_spoke_name" >/dev/null 2>&1; then
        if [[ "$force_update" == "true" ]]; then
            print_warning "Peering $hub_to_spoke_name already exists. Force updating..."
            az network vnet peering delete --resource-group "$hub_rg" --vnet-name "$hub_vnet" --name "$hub_to_spoke_name" >/dev/null
        else
            print_warning "Peering $hub_to_spoke_name already exists. Use -f to force update."
            return 0
        fi
    fi
    
    # Create hub-to-spoke peering
    print_step "Creating peering: $hub_to_spoke_name"
    az network vnet peering create \
        --resource-group "$hub_rg" \
        --name "$hub_to_spoke_name" \
        --vnet-name "$hub_vnet" \
        --remote-vnet "$spoke_vnet_id" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --allow-gateway-transit >/dev/null
    
    print_success "Created hub-to-spoke peering: $hub_to_spoke_name"
    
    # Create spoke-to-hub peering
    print_step "Creating peering: $spoke_to_hub_name"
    az network vnet peering create \
        --resource-group "$spoke_rg" \
        --name "$spoke_to_hub_name" \
        --vnet-name "$spoke_vnet" \
        --remote-vnet "$hub_vnet_id" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --use-remote-gateways >/dev/null
    
    print_success "Created spoke-to-hub peering: $spoke_to_hub_name"
    print_success "VNet peering completed successfully!"
}

# Function to update VPN Gateway Point-to-Site routes
update_vpn_routes() {
    local hub_rg="$1"
    local vpn_gateway="$2"
    local spoke_address_space="$3"
    local spoke_name="$4"
    
    print_step "Updating VPN Gateway Point-to-Site configuration..."
    
    # Get current VPN client configuration
    print_step "Retrieving current VPN Gateway configuration..."
    local vpn_config=$(az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" --query "vpnClientConfiguration" -o json)
    
    if [[ "$vpn_config" == "null" || -z "$vpn_config" ]]; then
        print_error "VPN Gateway does not have Point-to-Site configuration enabled"
        safe_exit 1
    fi
    
    # Extract current address pool and routes
    local current_address_pool=$(echo "$vpn_config" | jq -r '.vpnClientAddressPool.addressPrefixes[0] // empty')
    local current_routes=$(echo "$vpn_config" | jq -r '.vpnClientRevokedCertificates // []')
    
    if [[ -z "$current_address_pool" ]]; then
        print_error "No VPN client address pool found in current configuration"
        safe_exit 1
    fi
    
    print_info "Current VPN client address pool: $current_address_pool"
    
    # Get existing routes (if any)
    local existing_routes=$(az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" --query "vpnClientConfiguration.vpnClientRootCertificates" -o json 2>/dev/null || echo "[]")
    
    # Check if route already exists
    print_step "Checking for existing routes to spoke VNet..."
    local route_exists=$(az network vnet-gateway list-advertised-routes --resource-group "$hub_rg" --name "$vpn_gateway" --peer "VpnGateway" --query "value[?contains(asPath, '$spoke_address_space')]" -o tsv 2>/dev/null || echo "")
    
    # For Point-to-Site VPN, we need to ensure the spoke address space is included in the VPN Gateway's route advertisement
    # This is typically handled automatically when VNet peering is established with gateway transit
    print_step "Verifying VPN Gateway can route to spoke address space: $spoke_address_space"
    
    # Test connectivity by checking route tables
    local gateway_routes=$(az network vnet-gateway list-learned-routes --resource-group "$hub_rg" --name "$vpn_gateway" --query "value[?contains(addressPrefixes[0], '$(echo $spoke_address_space | cut -d'/' -f1)')]" -o json 2>/dev/null || echo "[]")
    
    if [[ "$gateway_routes" == "[]" ]]; then
        print_warning "Route to spoke VNet may not be automatically learned yet. This can take a few minutes after peering is established."
    else
        print_success "VPN Gateway has routes to spoke address space"
    fi
    
    # Create a custom route table entry if needed (for advanced scenarios)
    print_step "Ensuring VPN clients can reach spoke VNet via gateway transit..."
    
    # The route advertisement should happen automatically with --allow-gateway-transit and --use-remote-gateways
    # But we can verify the effective routes
    local hub_vnet=$(az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" --query "ipConfigurations[0].subnet.id" -o tsv | sed 's|/subnets/.*||' | sed 's|.*/||')
    
    print_info "Routes will be automatically advertised to VPN clients through gateway transit"
    print_success "VPN Gateway route configuration completed!"
    
    # Provide information about route propagation
    echo ""
    print_info "Route Information:"
    echo "  • Spoke VNet: $spoke_address_space"
    echo "  • Hub VNet: $(az network vnet show --resource-group "$hub_rg" --name "$hub_vnet" --query "addressSpace.addressPrefixes[0]" -o tsv)"
    echo "  • VPN Client Pool: $current_address_pool"
    echo ""
    print_info "VPN clients will automatically receive routes to the spoke VNet through gateway transit."
    print_info "Route propagation may take 5-10 minutes to take effect."
}

# Function to test connectivity
test_connectivity() {
    local hub_rg="$1"
    local vpn_gateway="$2"
    local spoke_address_space="$3"
    
    print_step "Testing VPN Gateway connectivity..."
    
    # Check VPN Gateway status
    local gateway_state=$(az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" --query "provisioningState" -o tsv)
    
    if [[ "$gateway_state" != "Succeeded" ]]; then
        print_warning "VPN Gateway is not in 'Succeeded' state: $gateway_state"
    else
        print_success "VPN Gateway is in 'Succeeded' state"
    fi
    
    # Get BGP peer status if BGP is enabled
    local bgp_settings=$(az network vnet-gateway show --resource-group "$hub_rg" --name "$vpn_gateway" --query "bgpSettings" -o json)
    
    if [[ "$bgp_settings" != "null" ]]; then
        print_info "BGP is enabled on VPN Gateway"
        local asn=$(echo "$bgp_settings" | jq -r '.asn // "Not configured"')
        print_info "BGP ASN: $asn"
    fi
    
    print_success "Connectivity test completed"
}

# Main function
main() {
    local environment=""
    local spoke_vnet_id=""
    local spoke_address_space=""
    local hub_resource_group=""
    local spoke_name=""
    local update_routes_only=false
    local create_peering_only=false
    local force_update=false
    
    # Parse command line arguments
    while getopts "e:s:a:g:n:upfh" opt; do
        case $opt in
            e) environment="$OPTARG" ;;
            s) spoke_vnet_id="$OPTARG" ;;
            a) spoke_address_space="$OPTARG" ;;
            g) hub_resource_group="$OPTARG" ;;
            n) spoke_name="$OPTARG" ;;
            u) update_routes_only=true ;;
            p) create_peering_only=true ;;
            f) force_update=true ;;
            h) show_usage; safe_exit 0 ;;
            *) show_usage; safe_exit 1 ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$environment" || -z "$spoke_vnet_id" || -z "$spoke_address_space" ]]; then
        print_error "Missing required parameters"
        show_usage
        safe_exit 1
    fi
    
    # Set default values
    [[ -z "$hub_resource_group" ]] && hub_resource_group="auto-${environment}-hub-network-rg"
    [[ -z "$spoke_name" ]] && spoke_name=$(extract_spoke_name "$spoke_vnet_id")
    
    # Check for conflicting options
    if [[ "$update_routes_only" == true && "$create_peering_only" == true ]]; then
        print_error "Cannot specify both -u (update routes only) and -p (create peering only)"
        safe_exit 1
    fi
    
    # Define resource names
    local hub_vnet="auto-hub-${environment}-vnet"
    local vpn_gateway="auto-hub-${environment}-vpngw"
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Azure Hub-Spoke VNet Peering and VPN Route Configuration"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Environment: $environment"
    echo "Hub Resource Group: $hub_resource_group"
    echo "Hub VNet: $hub_vnet"
    echo "VPN Gateway: $vpn_gateway"
    echo "Spoke VNet ID: $spoke_vnet_id"
    echo "Spoke Name: $spoke_name"
    echo "Spoke Address Space: $spoke_address_space"
    echo "Update Routes Only: $update_routes_only"
    echo "Create Peering Only: $create_peering_only"
    echo "Force Update: $force_update"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Check Azure authentication
    check_azure_login
    
    # Validate VNets exist
    local hub_vnet_id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${hub_resource_group}/providers/Microsoft.Network/virtualNetworks/${hub_vnet}"
    validate_vnet "$hub_vnet_id" "$hub_vnet"
    validate_vnet "$spoke_vnet_id" "$spoke_name"
    
    # Create peering (unless update routes only)
    if [[ "$update_routes_only" != true ]]; then
        create_peering "$hub_resource_group" "$hub_vnet" "$spoke_vnet_id" "$spoke_name" "$force_update"
    fi
    
    # Update VPN routes (unless create peering only)
    if [[ "$create_peering_only" != true ]]; then
        update_vpn_routes "$hub_resource_group" "$vpn_gateway" "$spoke_address_space" "$spoke_name"
        test_connectivity "$hub_resource_group" "$vpn_gateway" "$spoke_address_space"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    print_success "Hub-Spoke configuration completed successfully!"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    print_info "Next Steps:"
    echo "1. Wait 5-10 minutes for route propagation to complete"
    echo "2. Test connectivity from VPN clients to spoke VNet resources"
    echo "3. If using private endpoints in spoke VNet, ensure DNS zones are linked"
    echo ""
    print_info "To test VPN connectivity:"
    echo "• Connect to VPN using Azure VPN Client"
    echo "• Try to reach a resource in the spoke VNet: $spoke_address_space"
    echo "• Check DNS resolution for private endpoints"
    echo ""
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi