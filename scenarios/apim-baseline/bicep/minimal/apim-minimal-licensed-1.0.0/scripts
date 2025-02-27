param(
    [Parameter(Mandatory=$true)]
    [string]$name,
    
    [Parameter(Mandatory=$false)]
    [switch]$exportReport
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

function Write-StatusMessage {
    param($message, $status = "INFO")
    $color = switch($status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Cyan" }
    }
    Write-Host "[$status] $message" -ForegroundColor $color
}

function Test-NetworkConfig {
    param($rgName)
    
    Write-StatusMessage "Checking network configuration..."
    
    $results = @{
        Passed = 0
        Failed = 0
        Warnings = 0
        Details = @()
    }
    
    try {
        # Check VNET
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name "vnet-$name" -ErrorAction Stop
        $results.Details += @{
            Component = "VNET"
            Status = "SUCCESS"
            Details = "Found: $($vnet.Name) with address space: $($vnet.AddressSpace.AddressPrefixes -join ', ')"
        }
        $results.Passed++
        
        # Check Subnet
        $subnet = $vnet.Subnets | Where-Object { $_.Name -eq 'apim' }
        if ($subnet) {
            $results.Details += @{
                Component = "Subnet"
                Status = "SUCCESS"
                Details = "Found APIM subnet: $($subnet.AddressPrefix)"
            }
            $results.Passed++
        }
        
        # Check NSG
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name "nsg-$name" -ErrorAction Stop
        $requiredRules = @('Management', 'ClientComm')
        $missingRules = $requiredRules | Where-Object {
            -not ($nsg.SecurityRules.Name -contains $_)
        }
        
        if ($missingRules) {
            $results.Details += @{
                Component = "NSG Rules"
                Status = "WARNING"
                Details = "Missing rules: $($missingRules -join ', ')"
            }
            $results.Warnings++
        } else {
            $results.Details += @{
                Component = "NSG Rules"
                Status = "SUCCESS"
                Details = "All required rules present"
            }
            $results.Passed++
        }
    }
    catch {
        $results.Details += @{
            Component = "Network"
            Status = "ERROR"
            Details = $_.Exception.Message
        }
        $results.Failed++
    }
    
    return $results
}

function Test-ApimConfig {
    param($rgName)
    
    Write-StatusMessage "Checking APIM configuration..."
    
    $results = @{
        Passed = 0
        Failed = 0
        Warnings = 0
        Details = @()
    }
    
    try {
        # Check APIM Service
        $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name "apim-$name" -ErrorAction Stop
        
        # Basic Configuration
        $results.Details += @{
            Component = "APIM Service"
            Status = "SUCCESS"
            Details = "Found: $($apim.Name), State: $($apim.ProvisioningState)"
        }
        $results.Passed++
        
        # SKU Check
        if ($apim.Sku.Name -eq 'Developer') {
            $results.Details += @{
                Component = "SKU"
                Status = "SUCCESS"
                Details = "Developer SKU with $($apim.Sku.Capacity) unit(s)"
            }
            $results.Passed++
        }
        
        # VNET Integration
        if ($apim.VirtualNetworkType -eq 'Internal') {
            $results.Details += @{
                Component = "VNET Integration"
                Status = "SUCCESS"
                Details = "Internal VNET mode configured"
            }
            $results.Passed++
        }
        
        # APIs Check
        $apis = Get-AzApiManagementApi -Context $apim
        $results.Details += @{
            Component = "APIs"
            Status = "INFO"
            Details = "Found $($apis.Count) API(s)"
        }
        
    }
    catch {
        $results.Details += @{
            Component = "APIM"
            Status = "ERROR"
            Details = $_.Exception.Message
        }
        $results.Failed++
    }
    
    return $results
}

# Main verification logic
try {
    $rgName = "rg-$name"
    Write-StatusMessage "Starting configuration verification for deployment: $name"
    
    # Verify resource group exists
    $rg = Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    Write-StatusMessage "Resource group found: $rgName"
    
    # Run checks
    $networkResults = Test-NetworkConfig -rgName $rgName
    $apimResults = Test-ApimConfig -rgName $rgName
    
    # Summarize results
    $totalPassed = $networkResults.Passed + $apimResults.Passed
    $totalFailed = $networkResults.Failed + $apimResults.Failed
    $totalWarnings = $networkResults.Warnings + $apimResults.Warnings
    
    Write-StatusMessage "`nVerification Summary:" "INFO"
    Write-StatusMessage "Passed: $totalPassed checks" "SUCCESS"
    Write-StatusMessage "Failed: $totalFailed checks" "ERROR"
    Write-StatusMessage "Warnings: $totalWarnings" "WARNING"
    
    if ($exportReport) {
        $report = @{
            Timestamp = Get-Date
            DeploymentName = $name
            ResourceGroup = $rgName
            Network = $networkResults
            APIM = $apimResults
            Summary = @{
                Passed = $totalPassed
                Failed = $totalFailed
                Warnings = $totalWarnings
            }
        }
        
        $reportPath = ".\verification-$name-$timestamp.json"
        $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath
        Write-StatusMessage "Detailed report exported to: $reportPath" "INFO"
    }
    
    if ($totalFailed -gt 0) {
        Write-StatusMessage "Verification completed with errors" "ERROR"
        exit 1
    }
    else {
        Write-StatusMessage "Verification completed successfully" "SUCCESS"
    }
}
catch {
    Write-StatusMessage "Verification failed: $_" "ERROR"
    exit 1
}