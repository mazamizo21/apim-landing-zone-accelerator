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

// Variables
var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'
var networkingResourceGroupName = 'rg-networking-${resourceSuffix}'
var sharedResourceGroupName = 'rg-shared-${resourceSuffix}'
var apimResourceGroupName = 'rg-apim-${resourceSuffix}'
var vnetName = 'vnet-apim-cs-${resourceSuffix}'

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

// Networking deployment
module networking 'networking/networking-no-waf.bicep' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

// Shared resources deployment (Key Vault, Application Insights)
module shared 'shared/shared-no-waf.bicep' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    resourceGroupName: sharedResourceGroup.name
    networkingResourceGroupName: networkingResourceGroup.name
    vnetName: vnetName
    privateEndpointSubnetid: networking.outputs.privateEndpointSubnetId
    workloadName: workloadName
    environment: environment
    identifier: identifier
  }
}

// APIM deployment
module apim 'apim/apim.bicep' = {
  scope: resourceGroup(apimResourceGroup.name)
  name: 'apimDeploy'
  params: {
    apimName: 'apim-${resourceSuffix}'
    location: location
    apimSubnetId: networking.outputs.apimSubnetId
    keyVaultName: shared.outputs.keyVaultName
    keyVaultResourceGroupName: sharedResourceGroup.name
    networkingResourceGroupName: networkingResourceGroup.name
    apimRG: apimResourceGroup.name
    vnetName: vnetName
    appInsightsName: shared.outputs.appInsightsName
    appInsightsId: shared.outputs.appInsightsId
    appInsightsInstrumentationKey: shared.outputs.appInsightsInstrumentationKey
  }
}

// Telemetry deployment
resource telemetrydeployment 'Microsoft.Resources/deployments@2021-04-01' = if (enableTelemetry) {
  name: 'pid-4b38ebad-5112-47a8-aa88-3cae1d66cabb-${uniqueString(subscription().id)}'
  location: location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = 'apim-${resourceSuffix}'
output keyVaultName string = shared.outputs.keyVaultName
