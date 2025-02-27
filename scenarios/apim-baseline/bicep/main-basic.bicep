targetScope = 'subscription'

@description('A short name for the workload being deployed')
@maxLength(8)
param workloadName string

@description('The environment for which the deployment is being executed')
@allowed([
  'dev'
  'uat'
  'prod'
  'dr'
])
param environment string

param identifier string
param location string = deployment().location

// Variables
var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'
var networkingResourceGroupName = 'rg-networking-${resourceSuffix}'
var sharedResourceGroupName = 'rg-shared-${resourceSuffix}'
var apimResourceGroupName = 'rg-apim-${resourceSuffix}'
var vnetName = 'vnet-apim-cs-${resourceSuffix}'
var apimName = 'apim-${resourceSuffix}'

// Resource Groups
resource networkingResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkingResourceGroupName
  location: location
}

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: sharedResourceGroupName
  location: location
}

resource apimResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: apimResourceGroupName
  location: location
}

// NSG
module nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'nsg-apim-${resourceSuffix}'
  params: {
    location: location
    name: 'nsg-apim-${resourceSuffix}'
    securityRules: [
      {
        name: 'APIM_Management_Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
      {
        name: 'APIM_Client_Inbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// Virtual Network
module vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: vnetName
  params: {
    location: location
    name: vnetName
    addressPrefixes: [
      '10.2.0.0/16'
    ]
    subnets: [
      {
        name: 'snet-apim-${resourceSuffix}'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: nsg.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe-${resourceSuffix}'
        properties: {
          addressPrefix: '10.2.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Log Analytics
module logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'log-${resourceSuffix}'
  params: {
    location: location
    name: 'log-${resourceSuffix}'
    sku: 'PerGB2018'
    retentionInDays: 30
  }
}

// Application Insights
module appInsights 'Microsoft.Insights/components@2020-02-02' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'appi-${resourceSuffix}'
  params: {
    location: location
    name: 'appi-${resourceSuffix}'
    kind: 'web'
    workspaceResourceId: logAnalytics.outputs.id
  }
}

// Key Vault
module keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'kv-${resourceSuffix}'
  params: {
    location: location
    name: 'kv-${resourceSuffix}'
    sku: 'standard'
    accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// APIM
module apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  scope: resourceGroup(apimResourceGroup.name)
  name: apimName
  params: {
    location: location
    name: apimName
    sku: {
      name: 'Developer'
      capacity: 1
    }
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso'
    virtualNetworkType: 'Internal'
    subnetResourceId: '${vnet.outputs.id}/subnets/snet-apim-${resourceSuffix}'
  }
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = apimName
output keyVaultName string = 'kv-${resourceSuffix}'
output vnetName string = vnetName
output apimUrl string = apimService.outputs.gatewayUrl
