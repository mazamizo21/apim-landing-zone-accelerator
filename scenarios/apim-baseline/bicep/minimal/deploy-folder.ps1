param(
    [Parameter(Mandatory=$false)]
    [string]$workloadName = "apim",
    [Parameter(Mandatory=$false)]
    [string]$environment = "dev",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus",
    [Parameter(Mandatory=$false)]
    [string]$identifier = -join ((65..90) + (97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
)

$ErrorActionPreference = 'Stop'

# Ensure we're in the correct directory
$baseDir = $PSScriptRoot
Set-Location $baseDir

Write-Host "Working directory: $baseDir"

# Create modules directory if it doesn't exist
$modulesDir = Join-Path $baseDir "modules"
if (-not (Test-Path $modulesDir)) {
    New-Item -ItemType Directory -Path $modulesDir -Force
}

# Array of module file contents
$moduleFiles = @{
    'networking.bicep' = @'
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
        }
      }
    ]
  }
}

output apimSubnetId string = '${vnet.id}/subnets/snet-apim-${resourceSuffix}'
'@

    'shared.bicep' = @'
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

output keyVaultName string = keyVault.name
'@

    'apim.bicep' = @'
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
    name: 'Developer'
    capacity: 1
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
}

# Create each module file
foreach ($module in $moduleFiles.GetEnumerator()) {
    $filePath = Join-Path $modulesDir $module.Key
    Set-Content -Path $filePath -Value $module.Value
    Write-Host "Created module file: $filePath"
}

# Create main deployment file
$mainBicep = @'
targetScope = 'subscription'

param workloadName string
param environment string
param location string
param identifier string

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

module networking 'modules/networking.bicep' = {
  scope: resourceGroup(networkingRG.name)
  name: 'networkingDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
  dependsOn: [
    networkingRG
  ]
}

module shared 'modules/shared.bicep' = {
  scope: resourceGroup(sharedRG.name)
  name: 'sharedDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
  }
  dependsOn: [
    sharedRG
  ]
}

module apim 'modules/apim.bicep' = {
  scope: resourceGroup(apimRG.name)
  name: 'apimDeploy'
  params: {
    location: location
    resourceSuffix: resourceSuffix
    apimSubnetId: networking.outputs.apimSubnetId
  }
  dependsOn: [
    apimRG
    networking
  ]
}

output apimName string = apim.outputs.apimName
output apimResourceGroup string = apimRG.name
'@

$mainBicepPath = Join-Path $baseDir "main.bicep"
Set-Content -Path $mainBicepPath -Value $mainBicep
Write-Host "Created main bicep file: $mainBicepPath"

# Verify files
Write-Host "`nVerifying deployment files:"
Get-ChildItem -Path $baseDir -Recurse -Include *.bicep | Format-Table Name, Directory -AutoSize

# Create deployment parameters
$parameters = @{
    workloadName = $workloadName
    environment = $environment
    location = $location
    identifier = $identifier
}

# Deploy
$deploymentName = "apim-$environment-$(Get-Date -Format 'yyyyMMddHHmm')"
Write-Host "`nStarting deployment: $deploymentName"

try {
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile $mainBicepPath `
        -TemplateParameterObject $parameters `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment succeeded!" -ForegroundColor Green
        
        $resourceSuffix = "$workloadName-$environment-$location-$identifier"
        $apimRG = "rg-apim-$resourceSuffix"
        $apimName = "apim-$resourceSuffix"
        
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $apimRG -Name $apimName
            Write-Host "`nAPIM Service Information:"
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
        }
    }
    else {
        Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
    }
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Error $_.Exception.Message
}