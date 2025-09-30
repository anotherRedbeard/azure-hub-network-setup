// Virtual Network Module
@description('Location for all resources')
param location string

@description('Virtual Network name')
param vnetName string

@description('Address prefix for the virtual network')
param addressPrefix string

@description('Gateway subnet address prefix')
param gatewaySubnetPrefix string

@description('DNS Resolver Inbound subnet address prefix')
param dnsResolverInboundSubnetPrefix string

@description('DNS Resolver Outbound subnet address prefix')
param dnsResolverOutboundSubnetPrefix string

@description('Tags to apply to all resources')
param tags object

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
          serviceEndpoints: []
        }
      }
      {
        name: 'snet-dnsresolver-inbound'
        properties: {
          addressPrefix: dnsResolverInboundSubnetPrefix
          serviceEndpoints: []
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'snet-dnsresolver-outbound'
        properties: {
          addressPrefix: dnsResolverOutboundSubnetPrefix
          serviceEndpoints: []
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output gatewaySubnetId string = '${vnet.id}/subnets/GatewaySubnet'
output dnsResolverInboundSubnetId string = '${vnet.id}/subnets/snet-dnsresolver-inbound'
output dnsResolverOutboundSubnetId string = '${vnet.id}/subnets/snet-dnsresolver-outbound'
