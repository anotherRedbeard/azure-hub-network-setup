# Azure Hub Network Setup

This repository contains Infrastructure as Code (IaC) for deploying an Azure hub network with VPN Gateway and Private DNS Resolver using Bicep and GitHub Actions.

## Overview

This solution deploys a complete hub network infrastructure including:

- **Virtual Network (VNet)** with multiple subnets:
  - `GatewaySubnet` - Required for VPN Gateway
  - `DNSInboundSubnet` - For Private DNS Resolver inbound endpoint
  - `DNSOutboundSubnet` - For Private DNS Resolver outbound endpoint
- **VPN Gateway** - Configured for Point-to-Site VPN with Azure AD authentication
- **Private DNS Resolver** - For DNS resolution of private Azure resources
- **VPN Client Configuration** - Automated generation of Azure VPN Client and OpenVPN profiles
- **Private DNS Zones** - Pre-configured for common Azure PaaS services

## Architecture

```
Azure Hub Network
├── Virtual Network (10.3.0.0/16 dev, 10.4.0.0/16 prod)
│   ├── GatewaySubnet (10.x.1.0/24)
│   ├── DNSInboundSubnet (10.x.2.0/28)
│   └── DNSOutboundSubnet (10.x.3.0/28)
├── VPN Gateway (Point-to-Site)
│   ├── Public IP Address
│   └── Client Address Pool (172.16.20x.0/24)
├── Private DNS Resolver
│   ├── Inbound Endpoint (for VPN clients)
│   └── Outbound Endpoint (for Azure resources)
└── Private DNS Zones
    ├── privatelink.azure-api.net
    ├── privatelink.azurewebsites.net
    └── privatelink.azurecr.io
```

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy-hub-network.yml    # GitHub Actions deployment pipeline
├── infra/
│   ├── RESOURCES.md                  # Resource documentation
│   └── bicep/
│       ├── main.bicep                # Main orchestrator
│       ├── main.dev.bicepparam       # Development environment parameters
│       ├── main.prd.bicepparam       # Production environment parameters
│       └── modules/
│           ├── vnet.bicep            # Virtual Network module
│           ├── vpn-gateway.bicep     # VPN Gateway module
│           └── dns-resolver.bicep    # DNS Resolver module
├── scripts/
│   ├── README.md                     # Script documentation
│   └── extract-vpn-config.sh         # VPN configuration extraction tool
├── validate-deployment.sh            # Pre-deployment validation
└── README.md
```

## Prerequisites

1. **Azure Subscription** - An active Azure subscription
2. **Azure CLI** - For local testing (optional)
3. **GitHub Repository Secrets** - Configure the following secrets:
   - `AZURE_CLIENT_ID` - Service Principal Client ID  
   - `ENTRA_TENANT_ID` - Azure Tenant ID
   - `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID

### Setting up Azure Authentication

1. Create a Service Principal with Contributor access:

```bash
az ad sp create-for-rbac --name "gh-actions-hub-network" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

2. Configure federated credentials for GitHub Actions (recommended):

```bash
az ad app federated-credential create \
  --id <APPLICATION_ID> \
  --parameters '{
    "name": "github-federated",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<OWNER>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

3. Add the secrets to your GitHub repository settings.

## Deployment

### Using GitHub Actions (Recommended)

1. Navigate to the **Actions** tab in your GitHub repository
2. Select the **Deploy Azure Hub Network** workflow
3. Click **Run workflow**
4. Choose:
   - **Environment**: `dev` or `prod`
   - **Action**: 
     - `validate` - Validate Bicep templates only
     - `what-if` - Preview changes without deploying
     - `deploy` - Deploy infrastructure and extract VPN configuration
     - `extract-vpn` - Extract VPN configuration from existing deployment
5. Click **Run workflow**

### Using Azure CLI (Local)

```bash
# Validate templates
az bicep build --file infra/bicep/main.bicep

# Deploy to development
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters infra/parameters/dev.parameters.json

# Deploy to production
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters infra/parameters/prod.parameters.json
```

## VPN Configuration

This solution provides **Point-to-Site VPN** connectivity, allowing individual users to connect securely to Azure resources. After deployment, the workflow automatically generates VPN client configuration files.

### Generated Files

The workflow creates and uploads the following files as artifacts:

- **`azurevpnconfig.xml`** - Azure VPN Client profile with DNS resolver integration
- **`azure-hub-vpn-{environment}.ovpn`** - OpenVPN profile for cross-platform clients
- **`vpn-configuration.txt`** - Detailed setup instructions and network information

### Client Setup Instructions

#### For Azure VPN Client (Recommended)
1. Download the workflow artifacts containing `azurevpnconfig.xml`
2. Install Azure VPN Client:
   - **Windows**: Microsoft Store
   - **macOS**: App Store  
   - **iOS**: App Store
   - **Android**: Google Play Store
3. Import the `azurevpnconfig.xml` file
4. Connect using your Azure AD credentials

#### For OpenVPN Client
1. Download the workflow artifacts containing the `.ovpn` file
2. Install OpenVPN client on your device
3. Import the `.ovpn` profile
4. Connect using your Azure AD credentials

### DNS Resolution

Both VPN configurations are automatically configured with the Private DNS Resolver IP, enabling seamless access to:
- Private Azure resources (Storage Accounts, Key Vaults, etc.)
- Resources in peered virtual networks
- Custom private DNS zones

## Customization

### Environment Parameters

Edit the `.bicepparam` files in `infra/bicep/` to customize:

- **Virtual network address space** (`vnetAddressPrefix`)
- **Subnet address prefixes** (Gateway, DNS Inbound/Outbound subnets)
- **VPN Client address pool** (`vpnClientAddressPoolPrefix`)
- **VPN Gateway SKU** (`vpnGatewaySku`: VpnGw1, VpnGw2, VpnGw3)
- **Private DNS zones** (`dnsZones` array)
- **Resource naming** and tags

Example customization in `main.dev.bicepparam`:
```bicep
param vnetAddressPrefix = '10.5.0.0/16'  // Custom address space
param vpnGatewaySku = 'VpnGw2'            // Higher performance
param dnsZones = [                        // Add custom DNS zones
  'privatelink.database.windows.net'
  'privatelink.vaultcore.azure.net'
]
```

### Adding Additional Subnets

Edit `infra/bicep/modules/vnet.bicep` to add more subnets to the virtual network.

## Cost Considerations

Key resources with associated costs:

- **VPN Gateway**: Billed hourly based on SKU (VpnGw1 ~$140/month, VpnGw2 ~$380/month)
- **Public IP Address**: ~$3-5/month
- **Private DNS Resolver**: ~$0.40/hour for the resolver + $0.10/million queries
- **Virtual Network**: No charge

**Estimated monthly cost for dev environment**: ~$150-200
**Estimated monthly cost for prod environment**: ~$400-450

## Best Practices Implemented

- ✅ **Modular Bicep design** - Separate modules for each resource type
- ✅ **Environment-specific parameters** - Different configurations for dev/prod
- ✅ **Azure Verified Modules pattern** - Following AVM principles
- ✅ **Subscription-level deployment** - Resource group created by template
- ✅ **Proper subnet delegation** - DNS Resolver subnets correctly delegated
- ✅ **Standard SKU Public IP** - Required for VPN Gateway
- ✅ **Comprehensive outputs** - All necessary information exported
- ✅ **Tagging strategy** - Consistent tags across all resources
- ✅ **GitHub Actions workflow** - Automated deployment with validation

## Implementation Guide for New Users

### 🚀 Quick Start Checklist

Follow this step-by-step guide to implement the Azure Hub Network in your subscription:

#### Phase 1: Pre-Deployment Setup

1. **Fork or Clone Repository**
   ```bash
   git clone https://github.com/yourusername/azure-hub-network-setup.git
   cd azure-hub-network-setup
   ```

2. **Create Azure Service Principal**
   ```bash
   # Create service principal with contributor access
   az ad sp create-for-rbac --name "gh-actions-hub-network" \
     --role contributor \
     --scopes /subscriptions/{your-subscription-id} \
     --sdk-auth
   
   # Note down the output - you'll need clientId for next step
   ```

3. **Configure Federated Credentials (Recommended)**
   ```bash
   # Replace placeholders with your values
   az ad app federated-credential create \
     --id <CLIENT_ID_FROM_STEP_2> \
     --parameters '{
       "name": "github-federated",
       "issuer": "https://token.actions.githubusercontent.com", 
       "subject": "repo:<YOUR_GITHUB_USERNAME>/<REPO_NAME>:ref:refs/heads/main",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

4. **Configure GitHub Secrets**
   
   Go to your GitHub repository → Settings → Secrets and variables → Actions
   
   Add these repository secrets:
   - `AZURE_CLIENT_ID`: Client ID from service principal creation
   - `ENTRA_TENANT_ID`: Your Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

5. **Customize Environment Parameters (Optional)**
   
   Edit `infra/bicep/main.dev.bicepparam` and `infra/bicep/main.prd.bicepparam`:
   - Adjust IP address ranges if they conflict with your existing networks
   - Modify VPN Gateway SKU based on your performance needs
   - Add additional private DNS zones for your services

#### Phase 2: Deployment

1. **Validate Configuration**
   - Go to Actions tab → "Deploy Azure Hub Network" → Run workflow
   - Environment: `dev`, Action: `validate`
   - Verify no errors in validation

2. **Preview Changes (Optional)**
   - Run workflow with Action: `what-if`
   - Review the resources that will be created

3. **Deploy Infrastructure**
   - Run workflow with Action: `deploy`
   - ⏱️ **Expected time: 45-60 minutes** (VPN Gateway takes the longest)
   - Monitor workflow progress in GitHub Actions

4. **Download VPN Configuration**
   - After successful deployment, download workflow artifacts
   - Extract files: `azurevpnconfig.xml`, `*.ovpn`, and `vpn-configuration.txt`

#### Phase 3: Post-Deployment Configuration

**✅ Immediate Tasks After Pipeline Completion:**

1. **Set Up VPN Client**
   - Install Azure VPN Client on your device
   - Import `azurevpnconfig.xml` configuration
   - Test connection using your Azure AD credentials

2. **Configure DNS Resolution** (Already automated)
   - ✅ Private DNS Resolver IP automatically added to VPN config
   - ✅ Common Azure service DNS zones pre-configured
   - ✅ DNS forwarding rules established

3. **Test Connectivity**
   ```bash
   # After connecting to VPN, test DNS resolution
   nslookup mystorageaccount.blob.core.windows.net
   
   # Should resolve to private IP if storage account has private endpoint
   ```

**🔧 Advanced Configuration (As Needed):**

4. **Peer Additional Virtual Networks**
   
   For each VNet you want to access via VPN:
   ```bash
   # Create peering from hub to spoke
   az network vnet peering create \
     --resource-group auto-dev-hub-network-rg \
     --name hub-to-spoke-vnet \
     --vnet-name auto-hub-dev-vnet \
     --remote-vnet /subscriptions/{sub-id}/resourceGroups/{spoke-rg}/providers/Microsoft.Network/virtualNetworks/{spoke-vnet}
   
   # Create reverse peering from spoke to hub
   az network vnet peering create \
     --resource-group {spoke-rg} \
     --name spoke-to-hub-vnet \
     --vnet-name {spoke-vnet} \
     --remote-vnet /subscriptions/{sub-id}/resourceGroups/auto-dev-hub-network-rg/providers/Microsoft.Network/virtualNetworks/auto-hub-dev-vnet
   ```

5. **Update VPN Client Address Routes** (If accessing peered VNets)
   
   Currently, VPN clients can access:
   - Hub VNet: `10.3.0.0/16` (dev) or `10.4.0.0/16` (prod)
   - Azure PaaS services via private endpoints
   
   To access additional peered VNets, you may need to:
   - Add routes to the VPN Gateway configuration
   - Or use the hub's DNS resolver for routing

### 🔄 Ongoing Management

**Extracting VPN Config Without Re-deployment:**
```bash
# Use the extract-vpn workflow action to get configs anytime
# Or run locally:
./scripts/extract-vpn-config.sh -e dev
```

**Adding New Users:**
- No additional configuration needed
- Users connect with their existing Azure AD credentials
- Access is controlled via Azure AD group membership

**Scaling Considerations:**
- Monitor VPN Gateway metrics for connection limits
- Upgrade VPN Gateway SKU if needed (VpnGw1 → VpnGw2 → VpnGw3)
- Consider VPN Gateway AZ variants for high availability

### 💡 Automation Opportunities

**Current Manual Steps That Could Be Automated:**
1. **VNet Peering**: Could be automated via additional Bicep modules
2. **Route Table Updates**: Could use Azure Route Server for dynamic routing

**Future Enhancement Ideas:**
- Azure DevOps pipeline alternative
- Monitoring and alerting automation
- Cost optimization automation

## Troubleshooting

### VPN Gateway deployment takes a long time

VPN Gateway deployment typically takes 30-45 minutes. This is normal behavior.

### DNS Resolver deployment fails

Ensure the subnets have proper delegation to `Microsoft.Network/dnsResolvers`.

### Authentication errors in GitHub Actions

Verify that all required secrets are configured correctly in repository settings.

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
