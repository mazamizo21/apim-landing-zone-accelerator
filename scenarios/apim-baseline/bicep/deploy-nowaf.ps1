# Set deployment parameters
$workloadName = "apim"
$environment = "dev"
$location = "eastus"
$random = -join ((65..90) + (97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
$identifier = $random.ToLower()

Write-Host "Starting APIM deployment (no WAF)..."
Write-Host "Parameters:"
Write-Host "  Workload Name: $workloadName"
Write-Host "  Environment: $environment"
Write-Host "  Location: $location"
Write-Host "  Identifier: $identifier"

# Ensure we have the required paths
$scriptPath = $PSScriptRoot
$modulesPath = Join-Path $scriptPath "modules"

# Verify all required files exist
$requiredFiles = @(
    (Join-Path $scriptPath "main-nowaf.bicep"),
    (Join-Path $modulesPath "networking.bicep"),
    (Join-Path $modulesPath "shared.bicep"),
    (Join-Path $modulesPath "apim.bicep")
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "Required file not found: $file"
        exit 1
    }
}

Write-Host "`nChecking for existing resource groups..."

# Clean up existing resource groups if they exist
$resourceSuffix = "$workloadName-$environment-$location-*"
$existingGroups = Get-AzResourceGroup | Where-Object { 
    $_.ResourceGroupName -like "rg-*-$resourceSuffix"
}

if ($existingGroups) {
    Write-Host "`nFound existing resource groups to remove:" -ForegroundColor Yellow
    $existingGroups | ForEach-Object { Write-Host "  $($_.ResourceGroupName)" }
    
    $confirmation = Read-Host "`nDo you want to remove these resource groups? (yes/no)"
    if ($confirmation -eq "yes") {
        $existingGroups | ForEach-Object {
            Write-Host "Removing resource group: $($_.ResourceGroupName)" -ForegroundColor Yellow
            Remove-AzResourceGroup -Name $_.ResourceGroupName -Force
        }
        Write-Host "Cleanup completed" -ForegroundColor Green
    }
    else {
        Write-Host "Cleanup skipped" -ForegroundColor Yellow
    }
}

# Create parameters for deployment
$parameters = @{
    workloadName = $workloadName
    environment = $environment
    identifier = $identifier
    location = $location
}

# Start the deployment
Write-Host "`nStarting deployment..." -ForegroundColor Green
$deploymentName = "apim-$environment-$(Get-Date -Format 'yyyyMMddHHmm')"

try {
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile (Join-Path $scriptPath "main-nowaf.bicep") `
        -TemplateParameterObject $parameters

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        # Get APIM URLs from outputs
        $apimName = $deployment.Outputs.apimName.Value
        $resourceSuffix = "$workloadName-$environment-$location-$identifier"
        $apimRG = "rg-apim-$resourceSuffix"
        
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $apimRG -Name $apimName
            Write-Host "`nAPIM Service Information:"
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
            Write-Host "`nResource Groups:"
            Write-Host "  APIM: $apimRG"
            Write-Host "  Networking: rg-networking-$resourceSuffix"
            Write-Host "  Shared: rg-shared-$resourceSuffix"
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
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