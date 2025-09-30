// Private DNS Resolver Module
@description('Location for all resources')
param location string

@description('DNS Resolver name')
param dnsResolverName string

@description('Virtual Network ID')
param vnetId string

@description('Inbound subnet ID')
param inboundSubnetId string

@description('Outbound subnet ID')
param outboundSubnetId string

@description('Tags to apply to all resources')
param tags object

// Private DNS Resolver
resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: dnsResolverName
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Inbound Endpoint
resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: dnsResolver
  name: 'inbound-endpoint'
  location: location
  properties: {
    ipConfigurations: [
      {
        subnet: {
          id: inboundSubnetId
        }
      }
    ]
  }
}

// Outbound Endpoint
resource outboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: dnsResolver
  name: 'outbound-endpoint'
  location: location
  properties: {
    subnet: {
      id: outboundSubnetId
    }
  }
}

// Outputs
output dnsResolverId string = dnsResolver.id
output dnsResolverName string = dnsResolver.name
output inboundEndpointIp string = inboundEndpoint.properties.ipConfigurations[0].privateIpAddress
output outboundEndpointId string = outboundEndpoint.id
