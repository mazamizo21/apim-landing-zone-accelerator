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
param enableTelemetry bool = true

// Variables for resource naming
var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'
var networkingResourceGroupName = 'rg-networking-${resourceSuffix}'
var sharedResourceGroupName = 'rg-shared-${resourceSuffix}'
var apimResourceGroupName = 'rg-apim-${resourceSuffix}'

// Create resource groups
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

// Deploy networking
module networking './networking/networking.bicep' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

// Deploy shared resources
module shared './shared/shared.bicep' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    resourceGroupName: sharedResourceGroup.name
    networkingResourceGroupName: networkingResourceGroup.name
    vnetName: 'vnet-apim-cs-${resourceSuffix}'
    privateEndpointSubnetid: networking.outputs.privateEndpointSubnetId
    workloadName: workloadName
    environment: environment
    identifier: identifier
  }
  dependsOn: [
    networking
  ]
}

// Deploy APIM
module apim './apim/apim.bicep' = {
  scope: resourceGroup(apimResourceGroup.name)
  name: 'apimDeploy'
  params: {
    apimName: 'apim-${resourceSuffix}'
    location: location
    apimSubnetId: networking.outputs.apimSubnetId
    appInsightsName: shared.outputs.appInsightsName
    appInsightsId: shared.outputs.appInsightsId
    appInsightsInstrumentationKey: shared.outputs.appInsightsInstrumentationKey
    keyVaultName: shared.outputs.keyVaultName
    keyVaultResourceGroupName: sharedResourceGroup.name
    networkingResourceGroupName: networkingResourceGroup.name
    apimRG: apimResourceGroup.name
    vnetName: 'vnet-apim-cs-${resourceSuffix}'
  }
  dependsOn: [
    shared
  ]
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = 'apim-${resourceSuffix}'
output keyVaultName string = shared.outputs.keyVaultName
