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

// NSG
module nsg './resources/nsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'nsgDeploy'
  params: {
    name: 'nsg-${baseName}'
    location: location
  }
}

// Virtual Network
module vnet './resources/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetDeploy'
  params: {
    name: 'vnet-${baseName}'
    location: location
    nsgId: nsg.outputs.nsgId
  }
  dependsOn: [
    nsg
  ]
}

// APIM Service
module apimService './resources/apimService.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apimDeploy'
  params: {
    name: 'apim-${baseName}'
    location: location
    subnetId: vnet.outputs.apimSubnetId
  }
  dependsOn: [
    vnet
  ]
}

output apimName string = apimService.outputs.apimName
output resourceGroup string = rg.name
