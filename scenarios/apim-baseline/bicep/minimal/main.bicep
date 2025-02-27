targetScope = 'subscription'

param workloadName string
param environment string
param location string
param identifier string

var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'

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

module networking 'modules/networking.bicep' = {
  scope: resourceGroup(networkingRG.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
  dependsOn: [
    networkingRG
  ]
}

module shared 'modules/shared.bicep' = {
  scope: resourceGroup(sharedRG.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
  dependsOn: [
    sharedRG
  ]
}

module apim 'modules/apim.bicep' = {
  scope: resourceGroup(apimRG.name)
  name: 'apimDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    apimSubnetId: networking.outputs.apimSubnetId
  }
  dependsOn: [
    apimRG
    networking
  ]
}

output apimName string = apim.outputs.apimName
output apimResourceGroup string = apimRG.name
