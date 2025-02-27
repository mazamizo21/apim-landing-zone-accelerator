param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apim$(Get-Random -Minimum 1000 -Maximum 9999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'

Write-Host "Starting basic APIM deployment...`n"
Write-Host "Parameters:"
Write-Host "  Name: $name"
Write-Host "  Location: $location"

# Verify Azure context
$context = Get-AzContext
if (-not $context) {
    Write-Error "Not connected to Azure. Please run Connect-AzAccount first."
    exit 1
}

Write-Host "`nUsing subscription: $($context.Subscription.Name)"

# Start deployment
$deploymentName = "apim-$(Get-Date -Format 'yyyyMMddHHmm')"

try {
    Write-Host "`nStarting deployment: $deploymentName"
    
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile "$PSScriptRoot\deploy-basic.json" `
        -TemplateParameterObject @{
            name = $name
            location = $location
        } `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        $rgName = $deployment.Outputs.resourceGroup.Value
        $apimName = $deployment.Outputs.apimName.Value
        
        Write-Host "`nDeployment Information:"
        Write-Host "  Resource Group: $rgName"
        Write-Host "  APIM Name: $apimName"
        
        try {
            Write-Host "`nRetrieving APIM details..."
            $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName -ErrorAction Stop
            
            Write-Host "`nAPIM Service Information:"
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
            
            Write-Host "`nNote: APIM service may take up to 40 minutes to fully provision."
            Write-Host "Check the Azure portal for detailed status."
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
            Write-Warning "Resource Group: $rgName"
            Write-Warning "APIM Name: $apimName"
            Write-Warning "Check the Azure portal for status and details."
        }
    }
    else {
        Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
        exit 1
    }
}
catch {
    Write-Error "`nDeployment failed:"
    Write-Error $_.Exception.Message
    exit 1
}