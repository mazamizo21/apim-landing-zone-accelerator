param(
    [Parameter(Mandatory=$true)]
    [string]$name,
    
    [Parameter(Mandatory=$false)]
    [switch]$force
)

$ErrorActionPreference = 'Stop'
$rgName = "rg-$name"

Write-Host "APIM Deployment Cleanup`n" -ForegroundColor Cyan
Write-Host "Resource Group to be deleted: $rgName"

# Verify Azure context
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Please run Connect-AzAccount first."
        exit 1
    }
    Write-Host "`nUsing Subscription: $($context.Subscription.Name)"
}
catch {
    Write-Error "Error checking Azure context: $_"
    exit 1
}

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Warning "Resource group '$rgName' not found."
    exit 0
}

# List resources that will be deleted
Write-Host "`nResources to be deleted:" -ForegroundColor Yellow
$resources = Get-AzResource -ResourceGroupName $rgName
foreach ($resource in $resources) {
    Write-Host "  - [$($resource.ResourceType)] $($resource.Name)"
}

# Confirm deletion
if (-not $force) {
    Write-Host "`nWARNING: This will delete all resources in the resource group." -ForegroundColor Red
    Write-Host "Type 'yes' to confirm deletion: " -NoNewline
    $confirmation = Read-Host
    if ($confirmation -ne "yes") {
        Write-Host "`nCleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Remove resource group
try {
    Write-Host "`nDeleting resource group $rgName..." -ForegroundColor Yellow
    Remove-AzResourceGroup -Name $rgName -Force
    Write-Host "Resource group deleted successfully." -ForegroundColor Green
}
catch {
    Write-Error "Error deleting resource group: $_"
    exit 1
}

Write-Host "`nCleanup completed.`n" -ForegroundColor Green