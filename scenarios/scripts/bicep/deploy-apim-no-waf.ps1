# Set environment variables
$env:AZURE_LOCATION = "eastus"
$env:RESOURCE_NAME_PREFIX = "apim"
$env:ENVIRONMENT_TAG = "dev"
$env:ENABLE_TELEMETRY = "false"

# Generate random identifier
$random = -join ((65..90) + (97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})
$env:RANDOM_IDENTIFIER = $random.ToLower()

Write-Host "Deployment Configuration:"
Write-Host "Location: $($env:AZURE_LOCATION)"
Write-Host "Resource Prefix: $($env:RESOURCE_NAME_PREFIX)"
Write-Host "Environment: $($env:ENVIRONMENT_TAG)"
Write-Host "Identifier: $($env:RANDOM_IDENTIFIER)"

# Create parameters file
$parameters = @{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        workloadName = @{ value = $env:RESOURCE_NAME_PREFIX }
        environment = @{ value = $env:ENVIRONMENT_TAG }
        identifier = @{ value = $env:RANDOM_IDENTIFIER }
        location = @{ value = $env:AZURE_LOCATION }
        enableTelemetry = @{ value = $false }
    }
}

# Save parameters to file
$parametersPath = Join-Path $PSScriptRoot "..\..\apim-baseline\bicep\parameters.json"
$parameters | ConvertTo-Json -Depth 10 | Set-Content -Path $parametersPath

# Copy no-WAF templates
$sourceDir = Join-Path $PSScriptRoot "..\..\apim-baseline\bicep"
Copy-Item -Path (Join-Path $sourceDir "main-no-waf.bicep") -Destination (Join-Path $sourceDir "main.bicep") -Force
Copy-Item -Path (Join-Path $sourceDir "networking\networking-no-waf.bicep") -Destination (Join-Path $sourceDir "networking\networking.bicep") -Force

# Deploy the solution
$deploymentName = "apim-baseline-$($env:RESOURCE_NAME_PREFIX)-$(Get-Date -Format 'yyyyMMddHHmm')"
$templateFile = Join-Path $sourceDir "main.bicep"

Write-Host "`nStarting deployment: $deploymentName"
Write-Host "Template file: $templateFile"
Write-Host "Parameters file: $parametersPath"

try {
    New-AzDeployment `
        -Name $deploymentName `
        -Location $env:AZURE_LOCATION `
        -TemplateFile $templateFile `
        -TemplateParameterFile $parametersPath

    # Get resource names
    $resourceSuffix = "$($env:RESOURCE_NAME_PREFIX)-$($env:ENVIRONMENT_TAG)-$($env:AZURE_LOCATION)-$($env:RANDOM_IDENTIFIER)"
    $apimRG = "rg-apim-$resourceSuffix"
    $apimName = "apim-$resourceSuffix"

    Write-Host "`nWaiting for APIM deployment to complete..."
    $retryCount = 0
    $maxRetries = 90 # 45 minutes
    do {
        $retryCount++
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $apimRG -Name $apimName -ErrorAction SilentlyContinue
            if ($apim -and $apim.ProvisioningState -eq "Succeeded") {
                Write-Host "`nAPIM deployment completed successfully!"
                Write-Host "APIM Gateway URL: $($apim.GatewayUrl)"
                Write-Host "APIM Portal URL: $($apim.PortalUrl)"
                break
            }
        }
        catch {
            Write-Host "Waiting for APIM... Attempt $retryCount of $maxRetries"
        }
        Start-Sleep -Seconds 30
    } while ($retryCount -lt $maxRetries)

} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}