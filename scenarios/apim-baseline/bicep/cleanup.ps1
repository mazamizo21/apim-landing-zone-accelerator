# Script to clean up all APIM-related resources
param(
    [Parameter(Mandatory=$false)]
    [string]$workloadName = "apim",
    
    [Parameter(Mandatory=$false)]
    [string]$environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

Write-Host "Starting cleanup of APIM resources..." -ForegroundColor Yellow

# Find all resource groups that match our naming pattern
$resourceGroups = Get-AzResourceGroup | Where-Object {
    $_.ResourceGroupName -like "rg-*-$workloadName-$environment-$location*"
}

if ($resourceGroups.Count -eq 0) {
    Write-Host "No matching resource groups found." -ForegroundColor Green
    exit
}

Write-Host "`nFound the following resource groups to delete:"
foreach ($rg in $resourceGroups) {
    Write-Host " - $($rg.ResourceGroupName)" -ForegroundColor Red
}

Write-Host "`nAre you sure you want to delete these resource groups? (yes/no)" -ForegroundColor Red
$confirmation = Read-Host

if ($confirmation -ne "yes") {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit
}

# Delete resource groups
foreach ($rg in $resourceGroups) {
    Write-Host "`nDeleting resource group: $($rg.ResourceGroupName)" -ForegroundColor Yellow
    
    try {
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob
        Write-Host "Deletion initiated for: $($rg.ResourceGroupName)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to delete resource group $($rg.ResourceGroupName): $_"
    }
}

Write-Host "`nResource group deletion jobs have been started in parallel..."
Write-Host "Waiting for all deletions to complete..."

# Wait for all jobs to complete
$jobs = Get-Job | Where-Object { $_.State -eq 'Running' }
if ($jobs) {
    $jobs | Wait-Job | Receive-Job
    Remove-Job -Job $jobs
}

Write-Host "`nCleanup completed. Please verify in the Azure portal that all resources have been removed." -ForegroundColor Green

# Additional DNS cleanup
Write-Host "`nChecking for private DNS zones..." -ForegroundColor Yellow
$dnsZones = Get-AzPrivateDnsZone -ErrorAction SilentlyContinue | Where-Object {
    $_.ResourceGroupName -like "*$workloadName-$environment-$location*"
}

if ($dnsZones) {
    Write-Host "Found private DNS zones to clean up..."
    foreach ($zone in $dnsZones) {
        Write-Host "Deleting DNS zone: $($zone.Name)"
        Remove-AzPrivateDnsZone -Name $zone.Name -ResourceGroupName $zone.ResourceGroupName -Force
    }
}

Write-Host "`nCleanup process completed." -ForegroundColor Green