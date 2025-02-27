param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apim$(Get-Random -Minimum 1000 -Maximum 9999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param($message, $type = "Info")
    $color = switch ($type) {
        "Success" { "Green" }
        "Error"   { "Red" }
        "Warning" { "Yellow" }
        default   { "Cyan" }
    }
    Write-Host "[$type] $message" -ForegroundColor $color
}

try {
    # Verify Azure context
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Please run Connect-AzAccount first."
    }
    
    Write-Step "Deploying APIM with minimal configuration"
    Write-Step "Deployment Parameters:"
    Write-Step "  Name: $name"
    Write-Step "  Location: $location"
    Write-Step "  Subscription: $($context.Subscription.Name)"
    
    # Verify template
    $templateFile = Join-Path $PSScriptRoot "deploy-min.json"
    if (-not (Test-Path $templateFile)) {
        throw "Template file not found: $templateFile"
    }
    
    # Deploy
    $deploymentName = "apim-$(Get-Date -Format 'yyyyMMddHHmm')"
    Write-Step "Starting deployment: $deploymentName..."
    
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
        Write-Step "Deployment succeeded!" "Success"
        $rgName = $deployment.Outputs.resourceGroup.Value
        $apimName = $deployment.Outputs.apimName.Value
        
        Write-Step "Resource Information:"
        Write-Step "  Resource Group: $rgName"
        Write-Step "  APIM Name: $apimName"
        
        # Get APIM details
        Write-Step "Retrieving APIM information..."
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName
            Write-Step "APIM Service URLs:"
            Write-Step "  Gateway: $($apim.GatewayUrl)"
            Write-Step "  Portal: $($apim.PortalUrl)"
            Write-Step "  Management: $($apim.ManagementApiUrl)"
            Write-Step "`nNote: Full provisioning may take up to 40 minutes." "Warning"
        }
        catch {
            Write-Step "APIM service is still provisioning. Check the Azure portal for status." "Warning"
        }
        
        Write-Step "To monitor the deployment:"
        Write-Step "  1. Open Azure Portal: https://portal.azure.com"
        Write-Step "  2. Navigate to Resource Group: $rgName"
        Write-Step "  3. Check APIM service status"
    }
    else {
        throw "Deployment failed with status: $($deployment.ProvisioningState)"
    }
}
catch {
    Write-Step "Deployment failed: $_" "Error"
    Write-Step "Check the Azure portal for more details." "Error"
    exit 1
}