$minimalPath = $PSScriptRoot
Write-Host "Setting up minimal deployment environment in: $minimalPath`n"

# Create the Bicep content as strings
$mainBicep = @'
targetScope = 'subscription'

param workloadName string
param environment string
param identifier string
param location string = deployment().location

var resourceSuffix = '${workloadName}-${environment}-${location}-${identifier}'

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

module networking 'networking.bicep' = {
  scope: resourceGroup(networkingRG.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

module shared 'shared.bicep' = {
  scope: resourceGroup(sharedRG.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
}

module apim 'apim.bicep' = {
  scope: resourceGroup(apimRG.name)
  name: 'apimDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    apimSubnetId: networking.outputs.apimSubnetId
  }
}
'@

$networkingBicep = @'
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

output apimSubnetId string = '${vnet.id}/subnets/snet-apim-${resourceSuffix}'
'@

$sharedBicep = @'
param location string
param resourceSuffix string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${resourceSuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: 'kv-${resourceSuffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}
'@

$apimBicep = @'
param location string
param resourceSuffix string
param apimSubnetId string

var apimName = 'apim-${resourceSuffix}'

resource apimIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${apimName}'
  location: location
}

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
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso API Management'
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
  }
}

output apimName string = apimService.name
output apimUrl string = apimService.properties.gatewayUrl
'@

# Create files
$files = @{
    'main.bicep' = $mainBicep
    'networking.bicep' = $networkingBicep
    'shared.bicep' = $sharedBicep
    'apim.bicep' = $apimBicep
}

foreach ($file in $files.GetEnumerator()) {
    $path = Join-Path $minimalPath $file.Key
    Write-Host "Creating $($file.Key)..."
    Set-Content -Path $path -Value $file.Value
}

Write-Host "`nVerifying files:"
Get-ChildItem -Path $minimalPath -Filter *.bicep | Format-Table Name, Length

Write-Host "`nRun 'az bicep build --file main.bicep' to validate the templates"