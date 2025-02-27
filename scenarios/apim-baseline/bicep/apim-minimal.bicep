targetScope = 'subscription'

// Parameters
param workloadName string
param environment string
param identifier string
param location string = deployment().location

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

// NSG
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

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet-apim-${resourceSuffix}'
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

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceSuffix}'
  location: location
  scope: resourceGroup(sharedRG.name)
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Key Vault
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

// APIM Managed Identity
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${apimName}'
  location: location
  scope: resourceGroup(apimRG.name)
}

// API Management
resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  scope: resourceGroup(apimRG.name)
  sku: {
    capacity: 1
    name: 'Developer'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso API Management'
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnet.id}/subnets/snet-apim-${resourceSuffix}'
    }
  }
}

// Outputs
output apimName string = apimService.name
output apimUrl string = apimService.properties.gatewayUrl
output keyVaultName string = keyVault.name
output vnetName string = vnet.name
