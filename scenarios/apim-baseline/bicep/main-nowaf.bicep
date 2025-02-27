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
module networking './modules/networking/networking.bicep' = {
  scope: resourceGroup(networkingResourceGroup.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

// Shared resources deployment
module shared './modules/shared/shared.bicep' = {
  scope: resourceGroup(sharedResourceGroup.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

// APIM deployment
module apim './modules/apim/apim.bicep' = {
  scope: resourceGroup(apimResourceGroup.name)
  name: 'apimDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    apimSubnetId: networking.outputs.apimSubnetId
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso API Management'
  }
}

// Outputs
output networkingResourceGroupName string = networkingResourceGroup.name
output sharedResourceGroupName string = sharedResourceGroup.name
output apimResourceGroupName string = apimResourceGroup.name
output apimName string = apim.outputs.apimName
output apimUrl string = apim.outputs.apimUrl
output keyVaultName string = shared.outputs.keyVaultName
