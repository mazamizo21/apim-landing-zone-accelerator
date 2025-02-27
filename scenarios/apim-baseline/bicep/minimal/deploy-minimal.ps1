param(
    [Parameter(Mandatory=$false)]
    [string]$subscriptionId = (Get-AzContext).Subscription.Id,
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

Write-Host "Deploying APIM with minimal configuration...`n"
Write-Host "Parameters:"
Write-Host "  Subscription: $subscriptionId"
Write-Host "  Workload Name: $workloadName"
Write-Host "  Environment: $environment"
Write-Host "  Location: $location"
Write-Host "  Identifier: $identifier"

# Ensure we're in the right subscription
$context = Get-AzContext
if ($context.Subscription.Id -ne $subscriptionId) {
    Write-Host "`nSetting subscription context to: $subscriptionId"
    Set-AzContext -SubscriptionId $subscriptionId
}

# Build parameters object
$parameters = @{
    workloadName = $workloadName
    environment = $environment
    location = $location
    identifier = $identifier
}

try {
    # Create deployment name
    $deploymentName = "$workloadName-$environment-$(Get-Date -Format 'yyyyMMddHHmm')"
    
    Write-Host "`nStarting deployment: $deploymentName"
    
    # Deploy the template
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile "./unified.bicep" `
        -TemplateParameterObject $parameters `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        
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
            
            Write-Host "`nResource Groups Created:"
            Write-Host "  APIM: $apimRG"
            Write-Host "  Networking: rg-networking-$resourceSuffix"
            Write-Host "  Shared: rg-shared-$resourceSuffix"
            
            Write-Host "`nDeployment completed successfully! You can now access your APIM instance at: $($apim.GatewayUrl)"
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
            Write-Warning "Check the Azure portal for status and details."
        }
    }
    else {
        throw "Deployment failed with status: $($deployment.ProvisioningState)"
    }
}
catch {
    Write-Error "`nDeployment failed with error: $_"
    Write-Error $_.Exception.Message
    exit 1
}