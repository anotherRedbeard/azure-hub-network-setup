# Deployment Examples

This document provides examples and scenarios for deploying the Azure Hub Network infrastructure.

## Example 1: Development Environment Deployment

### What Gets Deployed

When deploying to the **dev** environment:

```yaml
Environment: dev
Location: eastus
Resource Group: rg-hub-network-dev

Virtual Network: vnet-hub-dev
  Address Space: 10.0.0.0/16
  Subnets:
    - GatewaySubnet: 10.0.1.0/24
    - snet-dnsresolver-inbound: 10.0.2.0/28
    - snet-dnsresolver-outbound: 10.0.3.0/28

VPN Gateway: vpngw-hub-dev
  SKU: VpnGw1
  Type: RouteBased VPN
  Public IP: Standard SKU (Static)

Private DNS Resolver: dnspr-hub-dev
  Inbound Endpoint: in snet-dnsresolver-inbound
  Outbound Endpoint: in snet-dnsresolver-outbound
```

### Estimated Deployment Time
- Virtual Network: ~1 minute
- VPN Gateway: **30-45 minutes** (longest component)
- Private DNS Resolver: ~3-5 minutes
- **Total: ~35-50 minutes**

### Estimated Monthly Cost
- VPN Gateway VpnGw1: ~$140
- Public IP Address: ~$4
- Private DNS Resolver: ~$290
- Virtual Network: Free
- **Total: ~$434/month**

## Example 2: Production Environment Deployment

### What Gets Deployed

When deploying to the **prod** environment:

```yaml
Environment: prod
Location: eastus
Resource Group: rg-hub-network-prod

Virtual Network: vnet-hub-prod
  Address Space: 10.1.0.0/16
  Subnets:
    - GatewaySubnet: 10.1.1.0/24
    - snet-dnsresolver-inbound: 10.1.2.0/28
    - snet-dnsresolver-outbound: 10.1.3.0/28

VPN Gateway: vpngw-hub-prod
  SKU: VpnGw2 (Higher performance)
  Type: RouteBased VPN
  Public IP: Standard SKU (Static)

Private DNS Resolver: dnspr-hub-prod
  Inbound Endpoint: in snet-dnsresolver-inbound
  Outbound Endpoint: in snet-dnsresolver-outbound
```

### Estimated Deployment Time
- Virtual Network: ~1 minute
- VPN Gateway: **30-45 minutes** (longest component)
- Private DNS Resolver: ~3-5 minutes
- **Total: ~35-50 minutes**

### Estimated Monthly Cost
- VPN Gateway VpnGw2: ~$380
- Public IP Address: ~$4
- Private DNS Resolver: ~$290
- Virtual Network: Free
- **Total: ~$674/month**

## Example 3: Workflow Usage

### Validate Only (No Deployment)
```yaml
Actions → Deploy Azure Hub Network → Run workflow
  Environment: dev
  Action: validate
```

This will:
1. Checkout code
2. Login to Azure
3. Validate all Bicep templates
4. Exit (no resources created)

### What-If Analysis
```yaml
Actions → Deploy Azure Hub Network → Run workflow
  Environment: dev
  Action: what-if
```

This will:
1. Checkout code
2. Login to Azure
3. Validate Bicep templates
4. Show what changes would be made
5. Exit (no resources created)

### Full Deployment
```yaml
Actions → Deploy Azure Hub Network → Run workflow
  Environment: dev
  Action: deploy
```

This will:
1. Checkout code
2. Login to Azure
3. Validate Bicep templates
4. Run what-if analysis
5. **Deploy all resources**
6. Extract VPN configuration
7. Upload configuration as artifact
8. Display summary

## Example 4: VPN Configuration Output

After a successful deployment, you'll receive a configuration file similar to:

```
========================================
Azure Hub Network VPN Configuration
========================================
Environment: dev
Deployment Date: 2024-01-15 10:30:00

VPN Gateway Details:
-------------------
Gateway Name: vpngw-hub-dev
Gateway Public IP: 20.50.30.40
Resource Group: rg-hub-network-dev
Virtual Network: vnet-hub-dev

DNS Resolver Details:
--------------------
Inbound Endpoint IP: 10.0.2.4

Next Steps:
----------
1. Create a Local Network Gateway for your on-premises network
2. Create a VPN Connection between the VPN Gateway and Local Network Gateway
3. Configure your on-premises VPN device with the shared key
4. Test connectivity between networks
========================================
```

## Example 5: Connecting On-Premises Network

After deployment, connect your on-premises network:

```bash
# 1. Create Local Network Gateway
az network local-gateway create \
  --resource-group rg-hub-network-dev \
  --name lng-onprem-datacenter \
  --gateway-ip-address 203.0.113.10 \
  --local-address-prefixes 192.168.0.0/16

# 2. Create VPN Connection
az network vpn-connection create \
  --resource-group rg-hub-network-dev \
  --name cn-hub-to-onprem \
  --vnet-gateway1 vpngw-hub-dev \
  --local-gateway2 lng-onprem-datacenter \
  --shared-key "YourSecureSharedKey123!"

# 3. Verify connection status
az network vpn-connection show \
  --resource-group rg-hub-network-dev \
  --name cn-hub-to-onprem \
  --query connectionStatus
```

## Example 6: Using DNS Resolver

Configure your Azure VMs to use the DNS Resolver:

```bash
# Get the DNS Resolver inbound endpoint IP
DNS_IP=$(az network private-dns-resolver inbound-endpoint show \
  --dns-resolver-name dnspr-hub-dev \
  --resource-group rg-hub-network-dev \
  --name inbound-endpoint \
  --query ipConfigurations[0].privateIpAddress -o tsv)

# Configure VNet DNS servers
az network vnet update \
  --resource-group rg-hub-network-dev \
  --name vnet-hub-dev \
  --dns-servers $DNS_IP
```

## Example 7: Customization

To customize the deployment:

1. **Change address spaces**: Edit `infra/parameters/dev.parameters.json`
   ```json
   "vnetAddressPrefix": {
     "value": "172.16.0.0/16"
   }
   ```

2. **Upgrade VPN Gateway**: Edit parameter file
   ```json
   "vpnGatewaySku": {
     "value": "VpnGw2"
   }
   ```

3. **Change location**: Edit parameter file
   ```json
   "location": {
     "value": "westus2"
   }
   ```

## Example 8: Cleanup

To remove all deployed resources:

```bash
# Delete the entire resource group
az group delete \
  --name rg-hub-network-dev \
  --yes \
  --no-wait

# Verify deletion
az group exists --name rg-hub-network-dev
```

**Note**: This will delete all resources in the resource group. Make sure you have backups if needed.

## Common Issues and Solutions

### Issue: VPN Gateway deployment timeout
**Solution**: VPN Gateway deployment can take up to 45 minutes. Be patient and monitor the deployment progress in Azure Portal.

### Issue: DNS Resolver subnet delegation error
**Solution**: Ensure subnets are properly delegated to `Microsoft.Network/dnsResolvers`. The Bicep templates handle this automatically.

### Issue: Authentication failed in GitHub Actions
**Solution**: Verify that all three secrets are configured correctly:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Issue: Insufficient permissions
**Solution**: Ensure the Service Principal has Contributor role at the subscription level:
```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```
