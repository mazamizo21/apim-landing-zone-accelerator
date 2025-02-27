targetScope = 'subscription'

@description('Base name for all resources')
param baseName string = 'apimdev'

@description('Azure region')
param location string = deployment().location

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${baseName}'
  location: location
}

// Deploy networking and APIM
module mainDeployment 'Microsoft.Resources/deployments@2021-04-01' = {
  scope: resourceGroup(rg.name)
  name: 'mainDeploy'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      variables: {}
      resources: [
        {
          name: 'nsg-${baseName}'
          type: 'Microsoft.Network/networkSecurityGroups'
          apiVersion: '2021-02-01'
          location: location
          properties: {
            securityRules: [
              {
                name: 'Management'
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
                name: 'ClientComm'
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
          name: 'vnet-${baseName}'
          type: 'Microsoft.Network/virtualNetworks'
          apiVersion: '2021-02-01'
          location: location
          dependsOn: [
            'nsg-${baseName}'
          ]
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
                    id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${baseName}')
                  }
                }
              }
            ]
          }
        }
        {
          name: 'apim-${baseName}'
          type: 'Microsoft.ApiManagement/service'
          apiVersion: '2021-08-01'
          location: location
          dependsOn: [
            'vnet-${baseName}'
          ]
          sku: {
            name: 'Developer'
            capacity: 1
          }
          properties: {
            publisherEmail: 'admin@contoso.com'
            publisherName: 'Contoso API Management'
            virtualNetworkType: 'Internal'
            virtualNetworkConfiguration: {
              subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-${baseName}', 'apim')
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
}

output apimName string = reference('mainDeploy').outputs.apimName.value
output resourceGroup string = rg.name
