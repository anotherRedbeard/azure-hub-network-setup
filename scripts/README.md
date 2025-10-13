# Azure VPN Configuration Extraction Script

This script extracts VPN client configuration from an Azure VPN Gateway and configures it with DNS resolver settings for seamless access to private Azure resources.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- An existing Azure Hub Network deployment with:
  - VPN Gateway configured for Point-to-Site connections
  - Private DNS Resolver with inbound endpoint

## Usage

### Basic Usage

```bash
# Extract VPN configuration for dev environment
./scripts/extract-vpn-config.sh -e dev

# Extract VPN configuration for prod environment  
./scripts/extract-vpn-config.sh -e prod
```

### Advanced Usage

```bash
# Use custom resource group name
./scripts/extract-vpn-config.sh -e dev -g my-custom-resource-group

# Save configurations to specific directory
./scripts/extract-vpn-config.sh -e dev -o ./vpn-configs

# Combine options
./scripts/extract-vpn-config.sh -e prod -g prod-hub-rg -o ./production-vpn
```

## Options

| Option | Description | Required | Default |
|--------|-------------|----------|---------|
| `-e ENVIRONMENT` | Environment name (dev, prod, etc.) | Yes | - |
| `-g RESOURCE_GROUP` | Resource group name | No | `auto-{environment}-hub-network-rg` |
| `-o OUTPUT_DIR` | Output directory for configuration files | No | Current directory |
| `-h` | Show help message | No | - |

## Generated Files

The script generates the following files:

1. **`vpn-configuration.txt`** - Comprehensive setup instructions and details
2. **`azurevpnconfig.xml`** - Azure VPN Client profile with DNS resolver integration
3. **`azure-hub-vpn-{environment}.ovpn`** - OpenVPN profile (if available)

## Expected Resource Naming Convention

The script expects resources to follow this naming pattern:

- **Resource Group**: `auto-{environment}-hub-network-rg`
- **VPN Gateway**: `auto-hub-{environment}-vpngw`
- **DNS Resolver**: `auto-hub-{environment}-dnspr`
- **Virtual Network**: `auto-hub-{environment}-vnet`

If your resources use different names, use the `-g` option to specify the resource group name.

## Features

### Features

- **Resource validation**: Ensures all required resources exist before configuration
- **Safe configuration**: Only configures existing resources, never creates new ones
- **Bidirectional peering**: Configures both hub-to-spoke and spoke-to-hub peerings
- **Gateway transit**: Enables spoke VNets to use existing hub VPN Gateway
- **DNS integration**: Links all existing hub DNS zones to spoke VNets
- **VPN route advertisement**: Adds spoke CIDR ranges to existing VPN Gateway
- **Idempotent operation**: Safe to run multiple times, skips existing configurations
- **Force reconfiguration**: Option to recreate existing peerings and DNS links
- **Comprehensive validation**: Pre-flight checks with clear error messages

## Troubleshooting

### Common Issues

1. **"Not logged in to Azure CLI"**
   ```bash
   az login
   ```

2. **"Resource group not found"**
   - Verify the resource group name
   - Use `-g` option to specify correct name
   - Ensure you have access to the subscription

3. **"VPN Gateway not found"**
   - Check that the VPN Gateway exists
   - Verify naming convention matches

4. **"DNS Resolver not found"**
   - Ensure Private DNS Resolver is deployed
   - Check resource naming convention

### Testing Locally

You can test the script locally to troubleshoot issues:

```bash
# Test with verbose output
bash -x ./scripts/extract-vpn-config.sh -e dev

# Test with specific resource group
./scripts/extract-vpn-config.sh -e dev -g your-resource-group-name
```

## Integration with GitHub Actions

The script is designed to work with the GitHub Actions workflow but can also be used independently. The workflow automatically:

- Uses deployment outputs when running after a deployment
- Falls back to resource lookup when using the "extract-vpn" action
- Uploads generated files as artifacts

## Local Development

For local development and testing:

```bash
# Make script executable (if not already)
chmod +x scripts/extract-vpn-config.sh

# Test the script
./scripts/extract-vpn-config.sh -e dev -o ./test-output

# Check generated files
ls -la ./test-output/
```

This approach allows you to iterate quickly on VPN configuration extraction without running the full deployment pipeline.

---

# Hub-Spoke VNet Peering and DNS Zone Linking Script

The `setup-hub-spoke-peering.sh` script configures existing Azure resources for hub-spoke connectivity. It creates VNet peering between existing hub and spoke VNets, links existing private DNS zones to both hub and spoke VNets, and leverages BGP for automatic VPN route advertisement to Point-to-Site clients.

## Prerequisites

**⚠️ All resources must already exist - this script only configures them:**

- Azure CLI installed and authenticated (`az login`)
- Hub VNet must already exist (`auto-hub-{environment}-vnet`)
- Spoke VNet must already exist and be accessible
- VPN Gateway must already exist (`auto-hub-{environment}-vpngw`) for route advertisement
- Private DNS zones must already exist in hub resource group
- Access to both hub and spoke resource groups with appropriate permissions

## Usage

### Basic Hub-Spoke Configuration

```bash
# Configure existing resources for hub-spoke connectivity
./scripts/setup-hub-spoke-peering.sh \
  -e dev \
  -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet'
```

### Advanced Configuration Examples

```bash
# Custom hub resource group and spoke name
./scripts/setup-hub-spoke-peering.sh \
  -e prod \
  -s '/subscriptions/12345/resourceGroups/app-rg/providers/Microsoft.Network/virtualNetworks/app-vnet' \
  -g 'custom-hub-rg' \
  -n 'application'
```

## Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `-e ENVIRONMENT` | Environment name (dev, prod, etc.) | Yes | - |
| `-s SPOKE_VNET_ID` | Full resource ID of spoke VNet | Yes | - |
| `-g HUB_RESOURCE_GROUP` | Hub resource group name | No | `auto-{environment}-hub-network-rg` |
| `-n SPOKE_NAME` | Friendly name for spoke (used in peering names) | No | Extracted from VNet ID |
| `-h` | Show help message | No | - |

## What the Script Does

**🔍 Resource Validation**
- Validates that hub VNet exists (`auto-hub-{environment}-vnet`)
- Validates that spoke VNet exists and is accessible
- Checks for VPN Gateway existence (warns if missing)
- Verifies private DNS zones are available for linking
- Ensures Azure CLI authentication is active

**⚙️ Configuration Steps**

### 1. VNet Peering Configuration
- **Hub-to-Spoke Peering**: Enables VNet access, forwarded traffic, and gateway transit
- **Spoke-to-Hub Peering**: Enables VNet access, forwarded traffic, and uses remote gateways
- Skips existing peerings unless force update is specified

### 2. Private DNS Zone Linking
- Discovers all existing private DNS zones in the hub resource group
- Creates VNet links from each DNS zone to the spoke VNet
- Enables automatic DNS resolution for private endpoints
- Supports force update to recreate existing links

### 3. VPN Gateway Route Advertisement (Automatic)
- BGP-enabled VPN Gateway automatically learns peered VNet routes
- Routes are advertised to Point-to-Site clients via BGP and gateway transit
- No manual route configuration needed for modern VPN deployments
- VPN clients automatically receive routes to spoke networks within 5-10 minutes

## Expected Resource Naming

The script expects hub resources to follow this naming pattern:

- **Hub Resource Group**: `auto-{environment}-hub-network-rg`
- **Hub VNet**: `auto-hub-{environment}-vnet`

## Key Features

- **Bidirectional Peering**: Creates both hub-to-spoke and spoke-to-hub peering
- **Gateway Transit**: Automatically configures gateway transit for VPN access
- **Automatic DNS Zone Discovery**: Finds and links all private DNS zones
- **DNS Zone Linking**: Links all hub DNS zones to both hub and spoke VNets
- **Automatic Route Propagation**: BGP handles VPN route advertisement automatically
- **Disconnected Peering Recovery**: Detects and fixes disconnected peerings
- **Error Handling**: Comprehensive error checking and validation
- **Idempotent Operations**: Safe to run multiple times, skips existing configurations
- **Colored Output**: Easy-to-read colored terminal output with clear status messages

## Troubleshooting

### Common Issues

1. **"VNet not found"**
   - Verify the VNet resource ID is correct
   - Ensure you have access to the subscription and resource group

2. **"Peering already exists"**
   - Script will detect existing peerings and skip them
   - If peering is disconnected, script will automatically recreate it

3. **"No private DNS zones found"**
   - Ensure the hub deployment completed successfully
   - Verify private DNS zones exist in the hub resource group

4. **"DNS link already exists"**
   - Script will detect existing DNS links and skip them
   - Links are created with format: `{spoke-name}-link` and `hub-{environment}-link`

### Testing Connectivity and DNS Resolution

After running the script:

```bash
# Test basic connectivity between VNets
ping 10.1.0.4  # Replace with actual spoke resource IP

# Test DNS resolution for private endpoints
nslookup mystorageaccount.blob.core.windows.net

# Should resolve to private IP if private endpoint exists
# VPN clients will also get DNS resolution through hub resolver
```

## Integration with Hub Network

This script is designed to work with the hub network infrastructure deployed by this repository. It automatically:

- Uses the standard resource naming conventions
- Configures gateway transit for VPN access  
- Links all private DNS zones for seamless name resolution
- Validates hub network components exist

For multiple spoke VNets, run the script once for each spoke with different parameters.