param apimName string
param location string
param apimSubnetId string
param appInsightsName string
param appInsightsId string
param appInsightsInstrumentationKey string
param keyVaultName string
param keyVaultResourceGroupName string
param networkingResourceGroupName string
param apimRG string
param vnetName string

@description('Publisher email required for API Management service.')
param publisherEmail string = 'admin@contoso.com'

@description('Publisher name required for API Management service.')
param publisherName string = 'Contoso'

var apimIdentityName = 'identity-${apimName}'

// Create User Assigned Identity
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: apimIdentityName
  location: location
}

// Deploy API Management
resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
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
    additionalLocations: []
  }
}

// Logger for Application Insights
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-08-01' = {
  parent: apimService
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
  parent: apimService
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

// Named Values
resource apimNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'environment'
  properties: {
    displayName: 'environment'
    value: 'development'
    secret: false
  }
}

// Echo API
resource echoApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  parent: apimService
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

// Starter subscription for Echo API
resource starterSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' = {
  parent: apimService
  name: 'starter'
  properties: {
    displayName: 'Starter'
    scope: '/apis'
    state: 'active'
  }
}

// Outputs
output apimName string = apimService.name
output apimUrl string = apimService.properties.gatewayUrl
output apimIdentityName string = apimIdentityName
output apimIdentityPrincipalId string = apimIdentity.properties.principalId
