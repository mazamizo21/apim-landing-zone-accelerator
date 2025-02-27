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

// Networking resources module
module networking 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(networkingResourceGroup.name)
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
          type: 'Microsoft.Network/networkSecurityGroups'
          apiVersion: '2021-02-01'
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
        {
          type: 'Microsoft.Network/virtualNetworks'
          apiVersion: '2021-02-01'
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
                    id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-apim-${resourceSuffix}')
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
          dependsOn: [
            'Microsoft.Network/networkSecurityGroups/nsg-apim-${resourceSuffix}'
          ]
        }
      ]
      outputs: {
        vnetName: {
          type: 'string'
          value: vnetName
        }
        apimSubnetId: {
          type: 'string'
          value: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-apim-${resourceSuffix}')
        }
        privateEndpointSubnetId: {
          type: 'string'
          value: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-pe-${resourceSuffix}')
        }
      }
    }
  }
}

// Shared resources module
module shared 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(sharedResourceGroup.name)
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
          type: 'Microsoft.OperationalInsights/workspaces'
          apiVersion: '2021-06-01'
          name: 'log-${resourceSuffix}'
          location: location
          properties: {
            sku: {
              name: 'PerGB2018'
            }
            retentionInDays: 30
          }
        }
        {
          type: 'Microsoft.Insights/components'
          apiVersion: '2020-02-02'
          name: 'appi-${resourceSuffix}'
          location: location
          kind: 'web'
          properties: {
            Application_Type: 'web'
            WorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', 'log-${resourceSuffix}')
          }
          dependsOn: [
            'Microsoft.OperationalInsights/workspaces/log-${resourceSuffix}'
          ]
        }
        {
          type: 'Microsoft.KeyVault/vaults'
          apiVersion: '2021-06-01-preview'
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
      ]
      outputs: {
        keyVaultName: {
          type: 'string'
          value: 'kv-${resourceSuffix}'
        }
        appInsightsName: {
          type: 'string'
          value: 'appi-${resourceSuffix}'
        }
        appInsightsId: {
          type: 'string'
          value: resourceId('Microsoft.Insights/components', 'appi-${resourceSuffix}')
        }
        appInsightsInstrumentationKey: {
          type: 'string'
          value: reference('Microsoft.Insights/components/appi-${resourceSuffix}', '2020-02-02').InstrumentationKey
        }
      }
    }
  }
}

// APIM module
module apim 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(apimResourceGroup.name)
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
          type: 'Microsoft.ManagedIdentity/userAssignedIdentities'
          apiVersion: '2018-11-30'
          name: 'id-${apimName}'
          location: location
        }
        {
          type: 'Microsoft.ApiManagement/service'
          apiVersion: '2021-08-01'
          name: apimName
          location: location
          sku: {
            capacity: 1
            name: 'Developer'
          }
          identity: {
            type: 'UserAssigned'
            userAssignedIdentities: {
              '${resourceId(apimResourceGroup.name, 'Microsoft.ManagedIdentity/userAssignedIdentities', 'id-${apimName}')}': {}
            }
          }
          properties: {
            publisherEmail: 'admin@contoso.com'
            publisherName: 'Contoso API Management'
            virtualNetworkType: 'Internal'
            virtualNetworkConfiguration: {
              subnetResourceId: '${reference('networkingDeploy').outputs.apimSubnetId.value}'
            }
          }
          dependsOn: [
            'Microsoft.ManagedIdentity/userAssignedIdentities/id-${apimName}'
          ]
        }
      ]
    }
  }
  dependsOn: [
    networking
    shared
  ]
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = apimName
output keyVaultName string = 'kv-${resourceSuffix}'
