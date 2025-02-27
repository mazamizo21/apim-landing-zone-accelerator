param(
    [Parameter(Mandatory=$false)]
    [string]$testName = "test$(Get-Random -Minimum 1000 -Maximum 9999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus",
    [Parameter(Mandatory=$false)]
    [switch]$cleanup
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

function Write-TestResult {
    param($component, $result, $details = "")
    $color = if ($result -eq "PASS") { "Green" } else { "Red" }
    Write-Host "[$result] $component $(if ($details) { "- $details" })" -ForegroundColor $color
}

function Test-Files {
    Write-Host "`nTesting solution files..." -ForegroundColor Cyan
    
    $requiredFiles = @(
        @{ Path = "deploy-min.ps1"; Type = "Script" },
        @{ Path = "deploy-min.json"; Type = "Template" },
        @{ Path = "health-check.ps1"; Type = "Script" },
        @{ Path = "monitor.ps1"; Type = "Script" },
        @{ Path = "verify-config.ps1"; Type = "Script" },
        @{ Path = "README.md"; Type = "Doc" },
        @{ Path = "QUICKSTART.md"; Type = "Doc" },
        @{ Path = "MAINTENANCE.md"; Type = "Doc" },
        @{ Path = "CHECKLIST.md"; Type = "Doc" }
    )
    
    $results = @{
        Pass = 0
        Fail = 0
        Details = @()
    }
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file.Path) {
            $content = Get-Content $file.Path
            if ($content) {
                Write-TestResult $file.Path "PASS" "$($file.Type) present and not empty"
                $results.Pass++
            }
            else {
                Write-TestResult $file.Path "FAIL" "File is empty"
                $results.Fail++
            }
        }
        else {
            Write-TestResult $file.Path "FAIL" "File not found"
            $results.Fail++
        }
    }
    
    return $results
}

function Test-ScriptSyntax {
    Write-Host "`nValidating PowerShell scripts..." -ForegroundColor Cyan
    
    $results = @{
        Pass = 0
        Fail = 0
        Details = @()
    }
    
    Get-ChildItem -Filter "*.ps1" | ForEach-Object {
        $syntaxErrors = $null
        [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName), [ref]$syntaxErrors)
        
        if ($syntaxErrors) {
            Write-TestResult $_.Name "FAIL" "$($syntaxErrors.Count) syntax errors found"
            $results.Fail++
        }
        else {
            Write-TestResult $_.Name "PASS" "Syntax validation successful"
            $results.Pass++
        }
    }
    
    return $results
}

function Test-Deployment {
    Write-Host "`nTesting deployment..." -ForegroundColor Cyan
    
    $results = @{
        Pass = 0
        Fail = 0
        Details = @()
    }
    
    try {
        # Verify Azure connection
        $context = Get-AzContext
        if (-not $context) { throw "Not connected to Azure" }
        Write-TestResult "Azure Connection" "PASS" "Connected to $($context.Subscription.Name)"
        $results.Pass++
        
        # Deploy test instance
        Write-Host "`nDeploying test APIM instance..." -ForegroundColor Yellow
        .\deploy-min.ps1 -name $testName -location $location
        
        # Wait for initial deployment
        Start-Sleep -Seconds 60
        
        # Validate deployment
        Write-Host "`nValidating deployment..." -ForegroundColor Yellow
        .\verify-config.ps1 -name $testName -detailed
        
        # Run health check
        Write-Host "`nRunning health check..." -ForegroundColor Yellow
        .\health-check.ps1 -name $testName -detailed -exportReport
        
        Write-TestResult "Deployment Process" "PASS" "Complete deployment test successful"
        $results.Pass++
    }
    catch {
        Write-TestResult "Deployment Process" "FAIL" $_.Exception.Message
        $results.Fail++
    }
    finally {
        if ($cleanup) {
            Write-Host "`nCleaning up test deployment..." -ForegroundColor Yellow
            try {
                .\cleanup.ps1 -name $testName -force
                Write-TestResult "Cleanup" "PASS" "Resources removed successfully"
                $results.Pass++
            }
            catch {
                Write-TestResult "Cleanup" "FAIL" $_.Exception.Message
                $results.Fail++
            }
        }
    }
    
    return $results
}

try {
    Write-Host "Starting solution validation..." -ForegroundColor Cyan
    Write-Host "Test Configuration:"
    Write-Host "  Name: $testName"
    Write-Host "  Location: $location"
    Write-Host "  Cleanup: $cleanup"
    
    $fileResults = Test-Files
    $syntaxResults = Test-ScriptSyntax
    $deployResults = Test-Deployment
    
    $totalPass = $fileResults.Pass + $syntaxResults.Pass + $deployResults.Pass
    $totalFail = $fileResults.Fail + $syntaxResults.Fail + $deployResults.Fail
    
    Write-Host "`nTest Summary:" -ForegroundColor Cyan
    Write-Host "  Duration: $([math]::Round(((Get-Date) - $startTime).TotalMinutes, 2)) minutes"
    Write-Host "  Total Tests: $($totalPass + $totalFail)"
    Write-Host "  Passed: $totalPass" -ForegroundColor Green
    Write-Host "  Failed: $totalFail" -ForegroundColor Red
    
    if ($totalFail -gt 0) {
        throw "Solution validation failed with $totalFail errors"
    }
}
catch {
    Write-Error "Solution validation failed: $_"
    exit 1
}