using './main.bicep'

param location = 'canadacentral'
param environmentName = 'dev'
param resourceGroupName = 'auto-dev-hub-network-rg'
param vnetAddressPrefix = '10.3.0.0/16'
param gatewaySubnetName = 'GatewaySubnet'
param gatewaySubnetPrefix = '10.3.1.0/24'
param dnsResolverInboundSubnetName = 'DNSInboundSubnet'
param dnsResolverInboundSubnetPrefix = '10.3.2.0/28'
param dnsResolverOutboundSubnetName = 'DNSOutboundSubnet'
param dnsResolverOutboundSubnetPrefix = '10.3.3.0/28'
param vpnClientAddressPoolPrefix = '172.16.202.0/24'
param vpnGatewaySku = 'VpnGw1'
param dnsForwardingRulesetName = 'auto-hub-dev-dnsfr'
param tags = {
  Environment: 'dev'
  ManagedBy: 'Bicep'
  Pipeline: 'GHActions'
  Project: 'HubNetwork'
}
param dnsZones = [
  'azure-api.net'
  'privatelink.azurewebsites.net'
  'privatelink.azurecr.io'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]
