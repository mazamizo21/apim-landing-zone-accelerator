param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apim$(Get-Random -Minimum 1000 -Maximum 9999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

Write-Host "APIM Deployment Script`n" -ForegroundColor Cyan
Write-Host "Parameters:"
Write-Host "  Name: $name"
Write-Host "  Location: $location"

# Verify Azure context
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Please run Connect-AzAccount first."
        exit 1
    }
    Write-Host "`nUsing Azure Context:" -ForegroundColor Cyan
    Write-Host "  Subscription: $($context.Subscription.Name)"
    Write-Host "  Tenant: $($context.Tenant.Id)"
}
catch {
    Write-Error "Error checking Azure context: $_"
    exit 1
}

# Verify template file exists
$templateFile = Join-Path $baseDir "deploy-basic.json"
if (-not (Test-Path $templateFile)) {
    Write-Error "Template file not found: $templateFile"
    exit 1
}

# Start deployment
$deploymentName = "apim-$(Get-Date -Format 'yyyyMMddHHmm')"

try {
    Write-Host "`nStarting deployment: $deploymentName" -ForegroundColor Yellow
    
    # Validate template before deployment
    Write-Host "Validating template..."
    $validation = Test-AzDeployment `
        -Location $location `
        -TemplateFile $templateFile `
        -TemplateParameterObject @{
            name = $name
            location = $location
        } `
        -ErrorAction Stop

    if ($validation) {
        Write-Warning "Template validation produced warnings:"
        $validation | Format-List
        Write-Host "Continue deployment? (Y/N)"
        $response = Read-Host
        if ($response -ne "Y") {
            Write-Host "Deployment cancelled by user."
            exit 0
        }
    }

    # Perform deployment
    Write-Host "`nDeploying resources..."
    $deployment = New-AzDeployment `
        -Name $deploymentName `
        -Location $location `
        -TemplateFile $templateFile `
        -TemplateParameterObject @{
            name = $name
            location = $location
        } `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        $rgName = $deployment.Outputs.resourceGroup.Value
        $apimName = $deployment.Outputs.apimName.Value
        
        Write-Host "`nDeployment Information:" -ForegroundColor Cyan
        Write-Host "  Resource Group: $rgName"
        Write-Host "  APIM Name: $apimName"
        
        try {
            Write-Host "`nRetrieving APIM details..."
            $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName -ErrorAction Stop
            
            Write-Host "`nAPIM Service Information:" -ForegroundColor Cyan
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
            
            Write-Host "`nImportant Notes:" -ForegroundColor Yellow
            Write-Host "  1. APIM service may take up to 40 minutes to fully provision"
            Write-Host "  2. The service is deployed in internal virtual network mode"
            Write-Host "  3. You'll need to configure DNS and networking for access"
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
    Write-Host "`nDeployment Details:" -ForegroundColor Red
    Write-Host "  Template: $templateFile"
    Write-Host "  Name: $name"
    Write-Host "  Location: $location"
    exit 1
}