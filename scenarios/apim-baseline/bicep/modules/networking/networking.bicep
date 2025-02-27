param location string
param resourceSuffix string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg-apim-${resourceSuffix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'APIM_Management_Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
      {
        name: 'APIM_Client_Inbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet-apim-cs-${resourceSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-apim-${resourceSuffix}'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pe-${resourceSuffix}'
        properties: {
          addressPrefix: '10.2.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output apimSubnetId string = '${vnet.id}/subnets/snet-apim-${resourceSuffix}'
output peSubnetId string = '${vnet.id}/subnets/snet-pe-${resourceSuffix}'
