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
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'nsg-apim-${resourceSuffix}'
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: vnetName
}

// Deploy Networking
module networkingDeploy 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'networkingDeploy'
  scope: resourceGroup(networkingResourceGroup.name)
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
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
                    id: resourceId(networkingResourceGroup.name, 'Microsoft.Network/networkSecurityGroups', 'nsg-apim-${resourceSuffix}')
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
            'nsg-apim-${resourceSuffix}'
          ]
        }
      ]
    }
  }
}

// Deploy Shared Resources
module sharedDeploy 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'sharedDeploy'
  scope: resourceGroup(sharedResourceGroup.name)
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
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
            WorkspaceResourceId: resourceId(sharedResourceGroup.name, 'Microsoft.OperationalInsights/workspaces', 'log-${resourceSuffix}')
          }
          dependsOn: [
            'log-${resourceSuffix}'
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
    }
  }
  dependsOn: [
    networkingDeploy
  ]
}

// Deploy APIM
module apimDeploy 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'apimDeploy'
  scope: resourceGroup(apimResourceGroup.name)
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: [
        {
          type: 'Microsoft.ApiManagement/service'
          apiVersion: '2021-08-01'
          name: apimName
          location: location
          sku: {
            capacity: 1
            name: 'Developer'
          }
          properties: {
            publisherEmail: 'admin@contoso.com'
            publisherName: 'Contoso API Management'
            virtualNetworkType: 'Internal'
            virtualNetworkConfiguration: {
              subnetResourceId: resourceId(networkingResourceGroup.name, 'Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-apim-${resourceSuffix}')
            }
          }
        }
      ]
    }
  }
  dependsOn: [
    networkingDeploy
    sharedDeploy
  ]
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = apimName
output keyVaultName string = 'kv-${resourceSuffix}'
