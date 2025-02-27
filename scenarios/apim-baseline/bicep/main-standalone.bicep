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

// Networking Resources
module networking 'networking.bicep' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    vnetName: vnetName
  }
}

// Shared Resources
module shared 'shared.bicep' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    networkingResourceGroupName: networkingResourceGroup.name
    vnetName: vnetName
    privateEndpointSubnetId: networking.outputs.privateEndpointSubnetId
  }
}

// APIM Resources
module apim 'apim.bicep' = {
  scope: resourceGroup(apimResourceGroup.name)
  name: 'apimDeploy'
  params: {
    apimName: apimName
    location: location
    apimSubnetId: networking.outputs.apimSubnetId
    appInsightsName: shared.outputs.appInsightsName
    appInsightsId: shared.outputs.appInsightsId
    appInsightsInstrumentationKey: shared.outputs.appInsightsInstrumentationKey
    keyVaultName: shared.outputs.keyVaultName
    keyVaultResourceGroupName: sharedResourceGroup.name
    networkingResourceGroupName: networkingResourceGroup.name
    apimRG: apimResourceGroup.name
    vnetName: vnetName
  }
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = apimName
output keyVaultName string = shared.outputs.keyVaultName

// Inline module definitions
module networking 'networking.bicep' = {
  resource apimNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
    name: 'nsg-apim-${resourceSuffix}'
    location: location
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
    name: vnetName
    location: location
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
              id: apimNsg.id
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
}

module shared 'shared.bicep' = {
  resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
    name: 'log-${resourceSuffix}'
    location: location
    properties: {
      sku: {
        name: 'PerGB2018'
      }
      retentionInDays: 30
    }
  }

  resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
    name: 'appi-${resourceSuffix}'
    location: location
    kind: 'web'
    properties: {
      Application_Type: 'web'
      WorkspaceResourceId: logAnalytics.id
    }
  }

  resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
    name: 'kv-${resourceSuffix}'
    location: location
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
}

module apim 'apim.bicep' = {
  resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
    name: 'id-${apimName}'
    location: location
  }

  resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
    name: apimName
    location: location
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
        subnetResourceId: networking.outputs.apimSubnetId
      }
    }
  }

  resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
    parent: apimService
    name: shared.outputs.appInsightsName
    properties: {
      loggerType: 'applicationInsights'
      description: 'Logger resources for APIM'
      credentials: {
        instrumentationKey: shared.outputs.appInsightsInstrumentationKey
      }
      isBuffered: true
      resourceId: shared.outputs.appInsightsId
    }
  }
}
