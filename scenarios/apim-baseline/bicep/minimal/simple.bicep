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
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: 'nsg-${baseName}'
}

// Deploy NSG
module nsgDeploy 'modules/nsg.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'nsgDeploy'
  params: {
    name: 'nsg-${baseName}'
    location: location
  }
}

// Deploy Virtual Network
module vnetDeploy 'modules/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetDeploy'
  params: {
    name: 'vnet-${baseName}'
    location: location
    nsgId: nsgDeploy.outputs.nsgId
  }
  dependsOn: [
    nsgDeploy
  ]
}

// Deploy APIM
module apimDeploy 'modules/apim.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'apimDeploy'
  params: {
    name: 'apim-${baseName}'
    location: location
    subnetId: vnetDeploy.outputs.subnetId
  }
  dependsOn: [
    vnetDeploy
  ]
}

output apimName string = apimDeploy.outputs.apimName
output resourceGroup string = rg.name
