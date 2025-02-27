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

// Networking Resources Deployment
module networkingDeployment './networking.bicep' = {
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

// Shared Resources Deployment
module sharedDeployment './shared.bicep' = {
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

// APIM Deployment
module apimDeployment './apim.bicep' = {
  scope: resourceGroup(apimRG.name)
  name: 'apimDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    apimSubnetId: networkingDeployment.outputs.apimSubnetId
  }
  dependsOn: [
    apimRG
    networkingDeployment
  ]
}

// Outputs
output apimName string = apimName
output apimRG string = apimRG.name
output networkingRG string = networkingRG.name
output sharedRG string = sharedRG.name
