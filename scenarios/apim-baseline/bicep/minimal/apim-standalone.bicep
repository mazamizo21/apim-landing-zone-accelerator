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

// Deploy networking resources
module networkingResources 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(networkingRG.name)
  name: 'networkingDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      variables: {}
      resources: [
        {
          name: 'nsg-apim-${resourceSuffix}'
          type: 'Microsoft.Network/networkSecurityGroups'
          apiVersion: '2021-02-01'
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
        {
          name: 'vnet-apim-cs-${resourceSuffix}'
          type: 'Microsoft.Network/virtualNetworks'
          apiVersion: '2021-02-01'
          location: location
          dependsOn: [
            'nsg-apim-${resourceSuffix}'
          ]
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
                    id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-apim-${resourceSuffix}')
                  }
                  privateEndpointNetworkPolicies: 'Disabled'
                  privateLinkServiceNetworkPolicies: 'Enabled'
                }
              }
            ]
          }
        }
      ]
      outputs: {
        apimSubnetId: {
          type: 'string'
          value: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-apim-cs-${resourceSuffix}', 'snet-apim-${resourceSuffix}')
        }
      }
    }
  }
}

// Deploy shared resources
module sharedResources 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(sharedRG.name)
  name: 'sharedDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      variables: {}
      resources: [
        {
          name: 'log-${resourceSuffix}'
          type: 'Microsoft.OperationalInsights/workspaces'
          apiVersion: '2021-06-01'
          location: location
          properties: {
            sku: {
              name: 'PerGB2018'
            }
            retentionInDays: 30
          }
        }
        {
          name: 'kv-${resourceSuffix}'
          type: 'Microsoft.KeyVault/vaults'
          apiVersion: '2021-06-01-preview'
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
      ]
    }
  }
}

// Deploy APIM
module apimResources 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(apimRG.name)
  name: 'apimDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      variables: {}
      resources: [
        {
          name: 'id-${apimName}'
          type: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          apiVersion: '2018-11-30'
          location: location
        }
        {
          name: apimName
          type: 'Microsoft.ApiManagement/service'
          apiVersion: '2021-08-01'
          location: location
          dependsOn: [
            'id-${apimName}'
          ]
          identity: {
            type: 'UserAssigned'
            userAssignedIdentities: {
              '${resourceId(apimRG.name, 'Microsoft.ManagedIdentity/userAssignedIdentities', 'id-${apimName}')}': {}
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
              subnetResourceId: reference(networkingResources.name).outputs.apimSubnetId.value
            }
          }
        }
      ]
    }
  }
  dependsOn: [
    networkingResources
  ]
}

// Outputs
output apimName string = apimName
output apimResourceGroup string = apimRG.name
output networkingResourceGroup string = networkingRG.name
output sharedResourceGroup string = sharedRG.name
