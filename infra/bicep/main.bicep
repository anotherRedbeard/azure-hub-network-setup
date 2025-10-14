// Main orchestrator for Azure Hub Network Setup
targetScope = 'subscription'

@description('Location for all resources')
param location string = 'eastus'

@description('Environment name (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Microsoft Tenant ID')
param tenantId string = ''

@description('Resource group name')
param resourceGroupName string = 'rg-hub-network-${environmentName}'

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Gateway subnet address prefix')
param gatewaySubnetName string = 'GatewaySubnet'

@description('Gateway subnet address prefix')
param gatewaySubnetPrefix string = '10.0.1.0/24'

@description('DNS resolver inbound subnet prefix')
param dnsResolverInboundSubnetName string = 'DNSInboundSubnet'

@description('DNS resolver outbound subnet prefix')
param dnsResolverInboundSubnetPrefix string = '10.0.3.0/28'

@description('DNS resolver inbound subnet prefix')
param dnsResolverOutboundSubnetName string = 'DNSOutboundSubnet'

@description('DNS resolver outbound subnet prefix')
param dnsResolverOutboundSubnetPrefix string = '10.0.3.0/28'

@description('Client IP address pool for VPN Gateway Point-to-Site connections')
param vpnClientAddressPoolPrefix string = '172.16.202.0/24'

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

@description('List of all the dns zones to create')
param dnsZones array = [
  'privatelink.azure-api.net'
  'privatelink.azurewebsites.net'
  'privatelink.azurecr.io'
]

module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'resourceGroupDeployment'
  params: {
    // Required parameters
    name: resourceGroupName
    // Non-required parameters
    location: location
    tags: tags
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'vnetDeployment'
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    name: 'auto-hub-${environmentName}-vnet'
    location: location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        name: gatewaySubnetName
        addressPrefix: gatewaySubnetPrefix
      }
      {
        name: dnsResolverInboundSubnetName
        addressPrefix: dnsResolverInboundSubnetPrefix
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: dnsResolverOutboundSubnetName
        addressPrefix: dnsResolverOutboundSubnetPrefix
        delegation: 'Microsoft.Network/dnsResolvers'
      }
    ]
    tags: tags
  }
}

module vpnGateway 'br/public:avm/res/network/virtual-network-gateway:0.8.0' = {
  name: 'virtualNetworkGatewayDeployment'
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    // Required parameters
    clusterSettings: {
      clusterMode: 'activeActiveBgp'
    }
    gatewayType: 'Vpn'
    name: 'auto-hub-${environmentName}-vpngw'
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    // Non-required parameters
    allowRemoteVnetTraffic: true
    disableIPSecReplayProtection: true
    enableBgpRouteTranslationForNat: true
    enablePrivateIpAddress: true
    skuName: vpnGatewaySku
    tags: tags
    // Pulled these settings from this document: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-entra-gateway#configure-vpn
    vpnClientAadConfiguration: {
      aadAudience: 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8'
      aadIssuer: 'https://sts.windows.net/${tenantId}/'
      aadTenant: 'https://login.microsoftonline.com/${tenantId}'
      vpnAuthenticationTypes: [
        'AAD'
      ]
      vpnClientProtocols: [
        'OpenVPN'
      ]
    }
    vpnClientAddressPoolPrefix: vpnClientAddressPoolPrefix
    vpnGatewayGeneration: 'Generation1'
    vpnType: 'RouteBased'
  }
}

// Deploy Private DNS Resolver
module dnsResolver 'br/public:avm/res/network/dns-resolver:0.5.4' = {
  name: 'dnsResolverDeployment'
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    // Required parameters
    name: 'auto-hub-${environmentName}-dnspr'
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    // Non-required parameters
    inboundEndpoints: [
      {
        name: 'auto-hub-${environmentName}-dnspr-in'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
      }
    ]
    location: location
    tags: tags
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = [for dnsZone in dnsZones: {
  name: 'privateDnsZoneDeployment-${dnsZone}'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: dnsZone
    location: 'global'
    virtualNetworkLinks: [
      {
        name: '${virtualNetwork.outputs.name}-vnetlink'
        registrationEnabled: false
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}]

// Outputs
output resourceGroupName string = resourceGroup.outputs.name
output vnetId string = virtualNetwork.outputs.resourceId
output vnetName string = virtualNetwork.outputs.name
output vpnGatewayId string = vpnGateway.outputs.resourceId
//primary public IP address
output vpnGatewayPublicIp string = vpnGateway.outputs.primaryPublicIpAddress ?? ''
output vpnGatewayName string = vpnGateway.outputs.name
output dnsResolverName string = dnsResolver.outputs.name
output dnsResolverInboundEndpointIp string = dnsResolver.outputs.inboundEndpointsObject[0].resourceId
