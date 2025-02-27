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

@description('A unique identifier for this deployment')
param identifier string

@description('Azure region for deployment')
param location string

// Variables
var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'
var apimName = 'apim-${resourceSuffix}'

// Resource Groups
resource networkingRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-networking-${resourceSuffix}'
  location: location
}

resource sharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-shared-${resourceSuffix}'
  location: location
}

resource apimRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-apim-${resourceSuffix}'
  location: location
}

// Networking Resources
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg-apim-${resourceSuffix}'
  location: location
  scope: resourceGroup(networkingRG.name)
  properties: {
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

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet-apim-cs-${resourceSuffix}'
  location: location
  scope: resourceGroup(networkingRG.name)
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-apim-${resourceSuffix}'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  dependsOn: [
    nsg
  ]
}

// Shared Resources
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${resourceSuffix}'
  location: location
  scope: resourceGroup(sharedRG.name)
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: 'kv-${resourceSuffix}'
  location: location
  scope: resourceGroup(sharedRG.name)
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
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

// APIM Resources
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${apimName}'
  location: location
  scope: resourceGroup(apimRG.name)
}

resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  scope: resourceGroup(apimRG.name)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimIdentity.id}': {}
    }
  }
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso API Management'
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnet.id}/subnets/snet-apim-${resourceSuffix}'
    }
  }
  dependsOn: [
    apimIdentity
    vnet
  ]
}

// Outputs
output apimName string = apimName
output apimUrl string = apimService.properties.gatewayUrl
output apimResourceGroup string = apimRG.name
output networkingResourceGroup string = networkingRG.name
output sharedResourceGroup string = sharedRG.name
