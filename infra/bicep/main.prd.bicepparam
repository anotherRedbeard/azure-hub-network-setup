using './main.bicep'

param location = 'canadacentral'
param environmentName = 'prd'
param resourceGroupName = 'auto-prd-hub-network-rg'
param vnetAddressPrefix = '10.7.0.0/16'
param gatewaySubnetName = 'GatewaySubnet'
param gatewaySubnetPrefix = '10.7.1.0/24'
param dnsResolverInboundSubnetName = 'DNSInboundSubnet'
param dnsResolverInboundSubnetPrefix = '10.7.2.0/28'
param dnsResolverOutboundSubnetName = 'DNSOutboundSubnet'
param dnsResolverOutboundSubnetPrefix = '10.7.3.0/28'
param vpnGatewaySku = 'VpnGw1'
param tags = {
  Environment: 'prd'
  ManagedBy: 'Bicep'
  Pipeline: 'GHActions'
  Project: 'HubNetwork'
}
