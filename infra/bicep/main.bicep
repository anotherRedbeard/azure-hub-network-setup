// Main orchestrator for Azure Hub Network Setup
targetScope = 'subscription'

@description('Location for all resources')
param location string = 'eastus'

@description('Environment name (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Resource group name')
param resourceGroupName string = 'rg-hub-network-${environmentName}'

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Gateway subnet address prefix')
param gatewaySubnetPrefix string = '10.0.1.0/24'

@description('DNS resolver inbound subnet prefix')
param dnsResolverInboundSubnetPrefix string = '10.0.2.0/28'

@description('DNS resolver outbound subnet prefix')
param dnsResolverOutboundSubnetPrefix string = '10.0.3.0/28'

@description('VPN Gateway SKU')
@allowed([
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
])
param vpnGatewaySku string = 'VpnGw1'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  ManagedBy: 'Bicep'
  Project: 'HubNetwork'
}

// Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy Virtual Network with Subnets
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  scope: rg
  params: {
    location: location
    vnetName: 'vnet-hub-${environmentName}'
    addressPrefix: vnetAddressPrefix
    gatewaySubnetPrefix: gatewaySubnetPrefix
    dnsResolverInboundSubnetPrefix: dnsResolverInboundSubnetPrefix
    dnsResolverOutboundSubnetPrefix: dnsResolverOutboundSubnetPrefix
    tags: tags
  }
}

// Deploy VPN Gateway
module vpnGateway 'modules/vpn-gateway.bicep' = {
  name: 'vpn-gateway-deployment'
  scope: rg
  params: {
    location: location
    gatewayName: 'vpngw-hub-${environmentName}'
    gatewaySku: vpnGatewaySku
    gatewaySubnetId: vnet.outputs.gatewaySubnetId
    tags: tags
  }
}

// Deploy Private DNS Resolver
module dnsResolver 'modules/dns-resolver.bicep' = {
  name: 'dns-resolver-deployment'
  scope: rg
  params: {
    location: location
    dnsResolverName: 'dnspr-hub-${environmentName}'
    vnetId: vnet.outputs.vnetId
    inboundSubnetId: vnet.outputs.dnsResolverInboundSubnetId
    outboundSubnetId: vnet.outputs.dnsResolverOutboundSubnetId
    tags: tags
  }
}

// Outputs
output resourceGroupName string = rg.name
output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName
output vpnGatewayId string = vpnGateway.outputs.gatewayId
output vpnGatewayPublicIp string = vpnGateway.outputs.gatewayPublicIp
output vpnGatewayName string = vpnGateway.outputs.gatewayName
output dnsResolverName string = dnsResolver.outputs.dnsResolverName
output dnsResolverInboundEndpointIp string = dnsResolver.outputs.inboundEndpointIp
