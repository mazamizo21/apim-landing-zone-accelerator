param name string
param location string
param subnetId string

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: name
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso API Management'
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
  }
}

// Echo API for testing
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

output apimName string = apim.name
output apimUrl string = apim.properties.gatewayUrl
