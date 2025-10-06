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

- **Automatic DNS Configuration**: Adds private DNS resolver IP to VPN client configurations
- **Multiple Client Support**: Generates both Azure VPN Client and OpenVPN profiles
- **Error Handling**: Comprehensive error checking and informative messages
- **Colored Output**: Easy-to-read colored terminal output
- **Fallback Configuration**: Creates manual configuration templates if automatic generation fails

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

# Hub-Spoke VNet Peering Script

The `setup-hub-spoke-peering.sh` script automates the creation of bidirectional VNet peering between the hub network and spoke VNets, while also configuring VPN Gateway routes for Point-to-Site clients.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- An existing Azure Hub Network deployment
- Access to both hub and spoke resource groups
- Spoke VNet must exist and be accessible

## Usage

### Basic Hub-Spoke Peering

```bash
# Create peering and configure VPN routes
./scripts/setup-hub-spoke-peering.sh \
  -e dev \
  -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' \
  -a '10.1.0.0/16'
```

### Advanced Usage Examples

```bash
# Custom hub resource group and spoke name
./scripts/setup-hub-spoke-peering.sh \
  -e prod \
  -s '/subscriptions/12345/resourceGroups/app-rg/providers/Microsoft.Network/virtualNetworks/app-vnet' \
  -a '10.2.0.0/16' \
  -g 'custom-hub-rg' \
  -n 'application'

# Only create peering (skip VPN route updates)
./scripts/setup-hub-spoke-peering.sh \
  -e dev \
  -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' \
  -a '10.1.0.0/16' \
  -p

# Only update VPN routes (skip peering creation)
./scripts/setup-hub-spoke-peering.sh \
  -e dev \
  -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' \
  -a '10.1.0.0/16' \
  -u

# Force update existing peering
./scripts/setup-hub-spoke-peering.sh \
  -e dev \
  -s '/subscriptions/12345/resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke-vnet' \
  -a '10.1.0.0/16' \
  -f
```

## Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `-e ENVIRONMENT` | Environment name (dev, prod, etc.) | Yes | - |
| `-s SPOKE_VNET_ID` | Full resource ID of spoke VNet | Yes | - |
| `-a ADDRESS_SPACE` | Spoke VNet address space (e.g., '10.1.0.0/16') | Yes | - |
| `-g HUB_RESOURCE_GROUP` | Hub resource group name | No | `auto-{environment}-hub-network-rg` |
| `-n SPOKE_NAME` | Friendly name for spoke (used in peering names) | No | Extracted from VNet ID |
| `-u` | Update VPN routes only (skip peering) | No | false |
| `-p` | Create peering only (skip VPN routes) | No | false |
| `-f` | Force update (overwrite existing peerings) | No | false |
| `-h` | Show help message | No | - |

## What the Script Does

### 1. VNet Peering Creation
- **Hub-to-Spoke Peering**: 
  - Enables VNet access and forwarded traffic
  - Allows gateway transit from hub to spoke
- **Spoke-to-Hub Peering**: 
  - Enables VNet access and forwarded traffic  
  - Uses remote gateways (hub VPN Gateway)

### 2. VPN Gateway Route Configuration
- Verifies Point-to-Site configuration exists
- Ensures spoke VNet routes are advertised to VPN clients
- Validates gateway transit is working properly
- Tests connectivity and route propagation

### 3. Validation and Testing
- Checks Azure CLI authentication
- Validates both hub and spoke VNets exist
- Verifies VPN Gateway state and configuration
- Provides connectivity testing guidance

## Expected Resource Naming

The script expects hub resources to follow this naming pattern:

- **Hub Resource Group**: `auto-{environment}-hub-network-rg`
- **Hub VNet**: `auto-hub-{environment}-vnet`  
- **VPN Gateway**: `auto-hub-{environment}-vpngw`

## Key Features

- **Bidirectional Peering**: Creates both hub-to-spoke and spoke-to-hub peering
- **Gateway Transit**: Automatically configures gateway transit for VPN access
- **Route Automation**: VPN clients automatically receive routes to spoke VNets
- **Error Handling**: Comprehensive error checking and validation
- **Flexible Options**: Can create peering only, update routes only, or both
- **Force Updates**: Can overwrite existing peerings if needed
- **Colored Output**: Easy-to-read colored terminal output

## Troubleshooting

### Common Issues

1. **"VNet not found"**
   - Verify the VNet resource ID is correct
   - Ensure you have access to the subscription and resource group

2. **"Peering already exists"**
   - Use `-f` flag to force update existing peering
   - Or manually delete existing peering first

3. **"VPN Gateway does not have Point-to-Site configuration"**
   - Ensure the hub deployment completed successfully
   - Verify VPN Gateway has P2S configuration enabled

4. **"Routes not appearing for VPN clients"**
   - Wait 5-10 minutes for route propagation
   - Disconnect and reconnect VPN client
   - Check that peering has gateway transit enabled

### Testing Connectivity

After running the script:

```bash
# Connect to VPN using Azure VPN Client
# Then test connectivity to spoke resources:

# Test basic connectivity
ping 10.1.0.4  # Replace with actual spoke resource IP

# Test DNS resolution (if spoke has private endpoints)
nslookup myapp.azurewebsites.net

# Check VPN client routes (Windows)
route print

# Check VPN client routes (macOS/Linux)  
netstat -rn
```

## Integration with Hub Network

This script is designed to work with the hub network infrastructure deployed by this repository. It automatically:

- Uses the standard resource naming conventions
- Configures gateway transit for VPN access
- Ensures proper route advertisement to VPN clients
- Validates hub network components exist

For multiple spoke VNets, run the script once for each spoke with different parameters.