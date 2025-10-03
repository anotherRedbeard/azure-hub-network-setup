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
2. **`azure-hub-vpn-{environment}.azurevpn`** - Azure VPN Client profile
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