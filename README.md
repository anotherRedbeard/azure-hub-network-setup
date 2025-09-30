# Azure Hub Network Setup

This repository contains Infrastructure as Code (IaC) for deploying an Azure hub network with VPN Gateway and Private DNS Resolver using Bicep and GitHub Actions.

## Overview

This solution deploys a complete hub network infrastructure including:

- **Virtual Network (VNet)** with multiple subnets:
  - `GatewaySubnet` - Required for VPN Gateway
  - `snet-dnsresolver-inbound` - For Private DNS Resolver inbound endpoint
  - `snet-dnsresolver-outbound` - For Private DNS Resolver outbound endpoint
- **VPN Gateway** - For secure site-to-site connectivity
- **Private DNS Resolver** - For DNS resolution between Azure and on-premises networks

## Architecture

```
Azure Hub Network
├── Virtual Network (10.0.0.0/16 or 10.1.0.0/16)
│   ├── GatewaySubnet (10.x.1.0/24)
│   ├── snet-dnsresolver-inbound (10.x.2.0/28)
│   └── snet-dnsresolver-outbound (10.x.3.0/28)
├── VPN Gateway
│   └── Public IP Address
└── Private DNS Resolver
    ├── Inbound Endpoint
    └── Outbound Endpoint
```

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy-hub-network.yml    # GitHub Actions deployment pipeline
├── infra/
│   ├── bicep/
│   │   ├── main.bicep                # Main orchestrator
│   │   └── modules/
│   │       ├── vnet.bicep            # Virtual Network module
│   │       ├── vpn-gateway.bicep     # VPN Gateway module
│   │       └── dns-resolver.bicep    # DNS Resolver module
│   └── parameters/
│       ├── dev.parameters.json       # Development environment parameters
│       └── prod.parameters.json      # Production environment parameters
└── README.md
```

## Prerequisites

1. **Azure Subscription** - An active Azure subscription
2. **Azure CLI** - For local testing (optional)
3. **GitHub Repository Secrets** - Configure the following secrets:
   - `AZURE_CLIENT_ID` - Service Principal Client ID
   - `AZURE_TENANT_ID` - Azure Tenant ID
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
     - `deploy` - Deploy infrastructure
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

After deployment, the workflow generates a VPN configuration file containing:

- VPN Gateway name and public IP address
- Resource group and virtual network details
- DNS Resolver inbound endpoint IP
- Next steps and example commands for setting up site-to-site connectivity

The configuration file is uploaded as a workflow artifact and displayed in the workflow summary.

### Connecting to On-Premises Network

1. Download the VPN configuration from workflow artifacts
2. Create a Local Network Gateway for your on-premises network:

```bash
az network local-gateway create \
  --resource-group <RESOURCE_GROUP> \
  --name lng-onprem \
  --gateway-ip-address <YOUR_ONPREM_PUBLIC_IP> \
  --local-address-prefixes <YOUR_ONPREM_ADDRESS_SPACE>
```

3. Create a VPN Connection:

```bash
az network vpn-connection create \
  --resource-group <RESOURCE_GROUP> \
  --name cn-hub-to-onprem \
  --vnet-gateway1 <VPN_GATEWAY_NAME> \
  --local-gateway2 lng-onprem \
  --shared-key <YOUR_SHARED_KEY>
```

4. Configure your on-premises VPN device with the same shared key

## Customization

### Environment Parameters

Edit the parameter files in `infra/parameters/` to customize:

- Virtual network address space
- Subnet address prefixes
- VPN Gateway SKU (VpnGw1, VpnGw2, VpnGw3, or AZ variants)
- Resource naming
- Tags

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
