# Azure Hub Network Resources

## Resources Created

### Virtual Network
- **Name Pattern**: `vnet-hub-{environment}`
- **Address Space**: 
  - Dev: `10.0.0.0/16`
  - Prod: `10.1.0.0/16`

### Subnets
1. **GatewaySubnet**
   - Required for VPN Gateway
   - Dev: `10.0.1.0/24`
   - Prod: `10.1.1.0/24`

2. **snet-dnsresolver-inbound**
   - For Private DNS Resolver inbound endpoint
   - Delegated to: `Microsoft.Network/dnsResolvers`
   - Dev: `10.0.2.0/28`
   - Prod: `10.1.2.0/28`

3. **snet-dnsresolver-outbound**
   - For Private DNS Resolver outbound endpoint
   - Delegated to: `Microsoft.Network/dnsResolvers`
   - Dev: `10.0.3.0/28`
   - Prod: `10.1.3.0/28`

### VPN Gateway
- **Name Pattern**: `vpngw-hub-{environment}`
- **Type**: VPN (RouteBased)
- **SKU**: 
  - Dev: `VpnGw1`
  - Prod: `VpnGw2`
- **Public IP**: Standard SKU, Static allocation

### Private DNS Resolver
- **Name Pattern**: `dnspr-hub-{environment}`
- **Inbound Endpoint**: Receives DNS queries from Azure VNet
- **Outbound Endpoint**: Forwards DNS queries to on-premises

## Deployment Order

The Bicep template deploys resources in the following order:
1. Resource Group
2. Virtual Network with Subnets
3. VPN Gateway (depends on VNet)
4. Private DNS Resolver (depends on VNet)

## Outputs

The deployment provides the following outputs:
- `resourceGroupName` - Name of the created resource group
- `vnetId` - Full resource ID of the virtual network
- `vnetName` - Name of the virtual network
- `vpnGatewayId` - Full resource ID of the VPN gateway
- `vpnGatewayPublicIp` - Public IP address of the VPN gateway
- `vpnGatewayName` - Name of the VPN gateway
- `dnsResolverName` - Name of the DNS resolver
- `dnsResolverInboundEndpointIp` - Private IP of the inbound endpoint

## Module Dependencies

```
main.bicep
├── modules/vnet.bicep (no dependencies)
├── modules/vpn-gateway.bicep (depends on vnet)
└── modules/dns-resolver.bicep (depends on vnet)
```
