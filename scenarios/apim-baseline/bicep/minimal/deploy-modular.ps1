# Set default parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apimdev$(Get-Random -Minimum 100 -Maximum 999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

Write-Host "Starting modular APIM deployment...`n"
Write-Host "Parameters:"
Write-Host "  Base Name: $name"
Write-Host "  Location: $location"

# Verify module files exist
$requiredFiles = @(
    "$baseDir\simple.bicep",
    "$baseDir\modules\nsg.bicep",
    "$baseDir\modules\vnet.bicep",
    "$baseDir\modules\apim.bicep"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "Required file not found: $file"
        exit 1
    }
}

Write-Host "`nVerifying files:"
Get-ChildItem -Path $baseDir -Recurse -Include *.bicep | Format-Table Name, Directory -AutoSize

# Start deployment
$deploymentName = "apim-$(Get-Date -Format 'yyyyMMddHHmm')"

try {
    Write-Host "`nStarting deployment: $deploymentName"
    
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile "$baseDir\simple.bicep" `
        -TemplateParameterObject @{
            baseName = $name
            location = $location
        } `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        $apimRG = "rg-$name"
        $apimName = "apim-$name"
        
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $apimRG -Name $apimName
            Write-Host "`nAPIM Service Information:"
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
            
            Write-Host "`nResource Group:"
            Write-Host "  $apimRG"
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
            Write-Warning "Check the Azure portal for status and details."
        }
    }
    else {
        Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
        exit 1
    }
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Error $_.Exception.Message
    exit 1
}