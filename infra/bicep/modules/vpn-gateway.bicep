// VPN Gateway Module
@description('Location for all resources')
param location string

@description('VPN Gateway name')
param gatewayName string

@description('VPN Gateway SKU')
param gatewaySku string

@description('Gateway subnet ID')
param gatewaySubnetId string

@description('Tags to apply to all resources')
param tags object

// Public IP for VPN Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-${gatewayName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: gatewayName
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

// Outputs
output gatewayId string = vpnGateway.id
output gatewayName string = vpnGateway.name
output gatewayPublicIp string = publicIp.properties.ipAddress
output publicIpId string = publicIp.id
