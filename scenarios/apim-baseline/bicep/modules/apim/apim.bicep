param location string
param resourceSuffix string
param apimSubnetId string
param publisherEmail string = 'admin@contoso.com'
param publisherName string = 'Contoso API Management'

var apimName = 'apim-${resourceSuffix}'

// Create managed identity for APIM
resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${apimName}'
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
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

// Echo API for testing
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

// Default subscription for Echo API
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' = {
  parent: apimService
  name: 'default'
  properties: {
    displayName: 'Default Subscription'
    scope: '/apis'
    state: 'active'
  }
}

// Outputs
output apimName string = apimService.name
output apimUrl string = apimService.properties.gatewayUrl
output identityPrincipalId string = apimIdentity.properties.principalId
