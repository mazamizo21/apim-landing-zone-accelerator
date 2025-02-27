targetScope = 'subscription'

@description('Base name for all resources')
param baseName string = 'apimdev'

@description('Azure region')
param location string = deployment().location

// Resource Groups
resource apimRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${baseName}'
  location: location
}

// NSG for APIM subnet
module nsg 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: apimRG
  name: 'nsgDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: [
        {
          name: 'nsg-${baseName}'
          type: 'Microsoft.Network/networkSecurityGroups'
          apiVersion: '2021-02-01'
          location: location
          properties: {
            securityRules: [
              {
                name: 'APIM_Management'
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
                name: 'Client_Communication'
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
      ]
      outputs: {
        nsgId: {
          type: 'string'
          value: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${baseName}')
        }
      }
    }
  }
}

// Virtual Network with APIM subnet
module vnet 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: apimRG
  name: 'vnetDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: [
        {
          name: 'vnet-${baseName}'
          type: 'Microsoft.Network/virtualNetworks'
          apiVersion: '2021-02-01'
          location: location
          properties: {
            addressSpace: {
              addressPrefixes: [
                '10.0.0.0/16'
              ]
            }
            subnets: [
              {
                name: 'apim'
                properties: {
                  addressPrefix: '10.0.1.0/24'
                  networkSecurityGroup: {
                    id: reference('nsgDeploy').outputs.nsgId.value
                  }
                }
              }
            ]
          }
        }
      ]
      outputs: {
        subnetId: {
          type: 'string'
          value: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-${baseName}', 'apim')
        }
      }
    }
  }
  dependsOn: [
    nsg
  ]
}

// API Management service
module apim 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: apimRG
  name: 'apimDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: [
        {
          name: 'apim-${baseName}'
          type: 'Microsoft.ApiManagement/service'
          apiVersion: '2021-08-01'
          location: location
          sku: {
            name: 'Developer'
            capacity: 1
          }
          properties: {
            publisherEmail: 'admin@contoso.com'
            publisherName: 'Contoso API Management'
            virtualNetworkType: 'Internal'
            virtualNetworkConfiguration: {
              subnetResourceId: reference('vnetDeploy').outputs.subnetId.value
            }
          }
        }
      ]
      outputs: {
        apimName: {
          type: 'string'
          value: 'apim-${baseName}'
        }
      }
    }
  }
  dependsOn: [
    vnet
  ]
}

// Outputs
output apimName string = reference('apimDeploy').outputs.apimName.value
output resourceGroup string = apimRG.name
