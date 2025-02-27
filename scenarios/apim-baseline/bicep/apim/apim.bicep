param apimName string
param location string
param apimSubnetId string

@description('Application Insights name')
param appInsightsName string

@description('Application Insights resource ID')
param appInsightsId string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Key Vault name')
param keyVaultName string

@description('Key Vault resource group name')
param keyVaultResourceGroupName string

@description('APIM resource group name')
param apimRG string

@description('Networking resource group name')
param networkingResourceGroupName string

@description('Virtual network name')
param vnetName string

@description('Publisher email required for API Management service')
param publisherEmail string = 'admin@contoso.com'

@description('Publisher name required for API Management service')
param publisherName string = 'Contoso API Management'

// Create managed identity for APIM
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${apimName}'
  location: location
}

// Deploy API Management
resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
  }
}

// Logger for Application Insights
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
  parent: apim
  name: appInsightsName
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger resources for APIM'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: appInsightsId
  }
}

// API Management diagnostics
resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2021-08-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
  }
}

// Echo API - for testing
resource echoApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  parent: apim
  name: 'echo-api'
  properties: {
    displayName: 'Echo API'
    path: 'echo'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
  }
}

// Outputs
output apimName string = apim.name
output apimIdentityName string = apimIdentity.name
output apimIdentityPrincipalId string = apimIdentity.properties.principalId
