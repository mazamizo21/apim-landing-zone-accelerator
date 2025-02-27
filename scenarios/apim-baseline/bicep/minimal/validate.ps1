param(
    [Parameter(Mandatory=$true)]
    [string]$name,
    
    [Parameter(Mandatory=$false)]
    [switch]$detailed
)

$ErrorActionPreference = 'Stop'
$rgName = "rg-$name"
$apimName = "apim-$name"

Write-Host "APIM Deployment Validation`n" -ForegroundColor Cyan
Write-Host "Target Resources:"
Write-Host "  Resource Group: $rgName"
Write-Host "  APIM Instance: $apimName"

# Verify Azure context
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Please run Connect-AzAccount first."
        exit 1
    }
    Write-Host "`nSubscription Context:" -ForegroundColor Cyan
    Write-Host "  Name: $($context.Subscription.Name)"
    Write-Host "  ID: $($context.Subscription.Id)"
}
catch {
    Write-Error "Error checking Azure context: $_"
    exit 1
}

# Check Resource Group
try {
    Write-Host "`nChecking Resource Group..." -ForegroundColor Cyan
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-Host "  Status: Found" -ForegroundColor Green
    Write-Host "  Location: $($rg.Location)"
    Write-Host "  Provisioning State: $($rg.ProvisioningState)"
}
catch {
    Write-Error "Resource Group '$rgName' not found."
    exit 1
}

# Check Network Resources
Write-Host "`nChecking Network Resources..." -ForegroundColor Cyan
try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name "vnet-$name" -ErrorAction Stop
    Write-Host "  VNET Status: Found" -ForegroundColor Green
    Write-Host "  Address Space: $($vnet.AddressSpace.AddressPrefixes -join ', ')"
    
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq 'apim' }
    Write-Host "  APIM Subnet: $($subnet.AddressPrefix)"
    
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name "nsg-$name" -ErrorAction Stop
    Write-Host "  NSG Status: Found" -ForegroundColor Green
    Write-Host "  Security Rules: $($nsg.SecurityRules.Count) rules configured"
}
catch {
    Write-Warning "Error checking network resources: $_"
}

# Check APIM Service
Write-Host "`nChecking APIM Service..." -ForegroundColor Cyan
try {
    $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName -ErrorAction Stop
    Write-Host "  Status: Found" -ForegroundColor Green
    Write-Host "  Provisioning State: $($apim.ProvisioningState)"
    Write-Host "  SKU: $($apim.Sku.Name) (Capacity: $($apim.Sku.Capacity))"
    Write-Host "  Gateway URL: $($apim.GatewayUrl)"
    Write-Host "  Management URL: $($apim.ManagementApiUrl)"
    Write-Host "  Portal URL: $($apim.PortalUrl)"
    Write-Host "  Virtual Network Type: $($apim.VirtualNetworkType)"
    
    if ($detailed) {
        Write-Host "`nAPI Details:" -ForegroundColor Cyan
        $apis = Get-AzApiManagementApi -Context $apim
        foreach ($api in $apis) {
            Write-Host "  - [$($api.ApiVersion)] $($api.Name)"
            Write-Host "    Path: $($api.Path)"
            Write-Host "    Protocols: $($api.Protocols -join ', ')"
        }
        
        Write-Host "`nNetwork Configuration:" -ForegroundColor Cyan
        Write-Host "  Subnet ID: $($apim.VirtualNetworkConfiguration.SubnetResourceId)"
    }
}
catch {
    Write-Warning "Error checking APIM service: $_"
}

# Overall Status
Write-Host "`nValidation Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group: OK" -ForegroundColor Green
Write-Host "  Networking: $(if ($vnet -and $nsg) { 'OK' } else { 'Warning' })" -ForegroundColor $(if ($vnet -and $nsg) { 'Green' } else { 'Yellow' })
Write-Host "  APIM Service: $(if ($apim) { 'OK' } else { 'Warning' })" -ForegroundColor $(if ($apim) { 'Green' } else { 'Yellow' })

if ($apim.ProvisioningState -ne "Succeeded") {
    Write-Warning "APIM service is still provisioning. This can take up to 40 minutes."
    Write-Warning "Check the Azure portal for detailed status."
}