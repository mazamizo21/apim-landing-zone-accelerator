# Set default parameters
param(
    [string]$workloadName = "apim",
    [string]$environment = "dev",
    [string]$location = "eastus",
    [string]$identifier = -join ((65..90) + (97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
)

Write-Host "Starting simplified APIM deployment...`n"
Write-Host "Parameters:"
Write-Host "  Workload Name: $workloadName"
Write-Host "  Environment: $environment"
Write-Host "  Location: $location"
Write-Host "  Identifier: $identifier"

# Create deployment parameters object
$parameters = @{
    workloadName = $workloadName
    environment = $environment
    identifier = $identifier
    location = $location
}

# Deploy the solution
$deploymentName = "apim-$environment-$(Get-Date -Format 'yyyyMMddHHmm')"

Write-Host "`nStarting deployment: $deploymentName"

try {
    # Deploy to subscription scope
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile ".\main-nowaf.bicep" `
        -TemplateParameterObject $parameters

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        # Get deployment outputs
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

        Write-Host "`nResource Groups:"
        Write-Host "  APIM: $apimRG"
        Write-Host "  Networking: rg-networking-$resourceSuffix"
        Write-Host "  Shared: rg-shared-$resourceSuffix"
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