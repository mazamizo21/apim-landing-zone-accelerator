param(
    [Parameter(Mandatory=$false)]
    [string]$action = "list",  # list, clean, or keep
    
    [Parameter(Mandatory=$false)]
    [string]$resourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$force
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param($message, $type = "INFO")
    $color = switch($type) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Cyan" }
    }
    Write-Host "[$type] $message" -ForegroundColor $color
}

function Get-ApimResourceGroups {
    Write-Status "Retrieving APIM resource groups..."
    
    $rgs = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like 'rg-apim*' }
    
    # Enhance with additional information
    $rgs | ForEach-Object {
        $resources = Get-AzResource -ResourceGroupName $_.ResourceGroupName
        $apim = $resources | Where-Object { $_.ResourceType -eq 'Microsoft.ApiManagement/service' }
        
        [PSCustomObject]@{
            ResourceGroupName = $_.ResourceGroupName
            Location = $_.Location
            CreatedTime = $_.Tags.CreatedTime
            ResourceCount = $resources.Count
            ApimName = $apim.Name
            ApimSku = if ($apim) { (Get-AzApiManagement -ResourceGroupName $_.ResourceGroupName -Name $apim.Name).Sku.Name } else { "N/A" }
            Status = if ($apim) { (Get-AzApiManagement -ResourceGroupName $_.ResourceGroupName -Name $apim.Name).ProvisioningState } else { "N/A" }
        }
    }
}

function Remove-ApimResourceGroup {
    param($rg)
    
    Write-Status "Removing resource group: $($rg.ResourceGroupName)" "WARNING"
    
    if (-not $force) {
        $confirm = Read-Host "Are you sure you want to remove $($rg.ResourceGroupName)? (y/n)"
        if ($confirm -ne 'y') {
            Write-Status "Skipping removal of $($rg.ResourceGroupName)" "INFO"
            return
        }
    }
    
    try {
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
        Write-Status "Successfully removed $($rg.ResourceGroupName)" "SUCCESS"
    }
    catch {
        Write-Status "Failed to remove $($rg.ResourceGroupName): $_" "ERROR"
    }
}

try {
    Write-Host "APIM Resource Management`n" -ForegroundColor Cyan
    
    switch ($action.ToLower()) {
        "list" {
            $rgs = Get-ApimResourceGroups
            
            if ($rgs) {
                Write-Host "`nFound APIM Resource Groups:" -ForegroundColor Yellow
                $rgs | Format-Table ResourceGroupName, Location, ApimName, ApimSku, Status, ResourceCount -AutoSize
            }
            else {
                Write-Status "No APIM resource groups found" "WARNING"
            }
        }
        
        "clean" {
            $rgs = Get-ApimResourceGroups
            
            if (-not $rgs) {
                Write-Status "No APIM resource groups found" "WARNING"
                return
            }
            
            Write-Host "`nFound Resource Groups:" -ForegroundColor Yellow
            for ($i=0; $i -lt $rgs.Count; $i++) {
                Write-Host "$($i+1). $($rgs[$i].ResourceGroupName) ($($rgs[$i].ApimName) - $($rgs[$i].Status))"
            }
            
            Write-Host "`nWhich resource groups would you like to remove? (comma-separated numbers, 'all', or 'none')"
            $selection = Read-Host "Selection"
            
            if ($selection -eq 'none') {
                Write-Status "No resource groups selected for removal" "INFO"
                return
            }
            
            if ($selection -eq 'all') {
                $rgs | ForEach-Object { Remove-ApimResourceGroup $_ }
            }
            else {
                $indices = $selection.Split(',') | ForEach-Object { $_.Trim() }
                foreach ($idx in $indices) {
                    if ($idx -match '^\d+$' -and [int]$idx -ge 1 -and [int]$idx -le $rgs.Count) {
                        Remove-ApimResourceGroup $rgs[[int]$idx-1]
                    }
                    else {
                        Write-Status "Invalid selection: $idx" "WARNING"
                    }
                }
            }
        }
        
        "keep" {
            if (-not $resourceGroupName) {
                Write-Status "Resource group name required for 'keep' action" "ERROR"
                return
            }
            
            $rgs = Get-ApimResourceGroups
            $keepRG = $rgs | Where-Object { $_.ResourceGroupName -eq $resourceGroupName }
            
            if (-not $keepRG) {
                Write-Status "Resource group '$resourceGroupName' not found" "ERROR"
                return
            }
            
            Write-Status "Keeping resource group: $resourceGroupName" "SUCCESS"
            $rgs | Where-Object { $_.ResourceGroupName -ne $resourceGroupName } | 
                ForEach-Object { Remove-ApimResourceGroup $_ }
        }
        
        default {
            Write-Status "Invalid action. Use 'list', 'clean', or 'keep'" "ERROR"
        }
    }
}
catch {
    Write-Status "Operation failed: $_" "ERROR"
    exit 1
}

# Usage examples:
# List all APIM resource groups:
# .\manage-resources.ps1 -action list

# Clean up specific resource groups (interactive):
# .\manage-resources.ps1 -action clean

# Keep one resource group and remove others:
# .\manage-resources.ps1 -action keep -resourceGroupName "rg-apim-prod" -force