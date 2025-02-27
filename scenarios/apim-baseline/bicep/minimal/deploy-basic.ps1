param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apimdev",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

Write-Host "Creating basic APIM deployment...`n"
Write-Host "Parameters:"
Write-Host "  Name: $name"
Write-Host "  Location: $location"

# Create modules directory
$modulesDir = Join-Path $baseDir "modules"
New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null

# Create networking module
$networkingContent = @'
param location string
param name string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg-${name}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Management'
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
        name: 'ClientComm'
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
  name: 'vnet-${name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-apim'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output apimSubnetId string = '${vnet.id}/subnets/snet-apim'
'@

# Create shared module
$sharedContent = @'
param location string
param name string

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: take('kv${name}', 24)
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
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

output kvName string = kv.name
'@

# Create APIM module
$apimContent = @'
param location string
param name string
param subnetId string

resource id 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${name}'
  location: location
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: 'apim-${name}'
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${id.id}': {}
    }
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

output apimUrl string = apim.properties.gatewayUrl
'@

# Create main bicep file
$mainContent = @'
targetScope = 'subscription'

param name string
param location string = deployment().location

resource networkingRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-net-${name}'
  location: location
}

resource sharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-shared-${name}'
  location: location
}

resource apimRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-apim-${name}'
  location: location
}

module networking 'modules/networking.bicep' = {
  scope: networkingRG
  name: 'networkingDeploy'
  params: {
    location: location
    name: name
  }
}

module shared 'modules/shared.bicep' = {
  scope: sharedRG
  name: 'sharedDeploy'
  params: {
    location: location
    name: name
  }
}

module apim 'modules/apim.bicep' = {
  scope: apimRG
  name: 'apimDeploy'
  params: {
    location: location
    name: name
    subnetId: networking.outputs.apimSubnetId
  }
}

output apimUrl string = apim.outputs.apimUrl
'@

# Write files
Set-Content -Path (Join-Path $modulesDir "networking.bicep") -Value $networkingContent
Set-Content -Path (Join-Path $modulesDir "shared.bicep") -Value $sharedContent
Set-Content -Path (Join-Path $modulesDir "apim.bicep") -Value $apimContent
Set-Content -Path (Join-Path $baseDir "main.bicep") -Value $mainContent

Write-Host "`nVerifying files..."
Get-ChildItem -Path $baseDir -Recurse -Include *.bicep | Format-Table Name, Directory -AutoSize

# Deploy
Write-Host "`nStarting deployment..."
$deployment = New-AzDeployment `
    -Name "apim-$(Get-Date -Format 'yyyyMMddHHmm')" `
    -Location $location `
    -TemplateFile (Join-Path $baseDir "main.bicep") `
    -TemplateParameterObject @{
        name = $name
        location = $location
    } `
    -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    Write-Host "`nDeployment succeeded!" -ForegroundColor Green
    Write-Host "APIM URL: $($deployment.Outputs.apimUrl.Value)"
}
else {
    Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
    exit 1
}