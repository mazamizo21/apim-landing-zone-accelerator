param location string
param resourceSuffix string

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '10.2.0.0/16'

@description('Address prefix for the APIM subnet')
param apimSubnetPrefix string = '10.2.1.0/24'

@description('Address prefix for private endpoints')
param privateEndpointSubnetPrefix string = '10.2.2.0/24'

var vnetName = 'vnet-apim-cs-${resourceSuffix}'
var apimSubnetName = 'snet-apim-${resourceSuffix}'
var privateEndpointSubnetName = 'snet-pe-${resourceSuffix}'

// Network Security Groups
resource apimNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
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

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: apimNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output apimSubnetId string = '${vnet.id}/subnets/${apimSubnetName}'
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'
