param(
    [Parameter(Mandatory=$false)]
    [string]$packageFile,
    [Parameter(Mandatory=$false)]
    [string]$testPath = ".\package-test",
    [Parameter(Mandatory=$false)]
    [switch]$cleanup
)

$ErrorActionPreference = 'Stop'
$testResults = @{
    Pass = 0
    Fail = 0
    Warnings = 0
}

function Write-TestResult {
    param($component, $status, $message)
    $color = switch ($status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$status] $component$(if($message){": $message"})" -ForegroundColor $color
    
    switch ($status) {
        "PASS" { $script:testResults.Pass++ }
        "FAIL" { $script:testResults.Fail++ }
        "WARN" { $script:testResults.Warnings++ }
    }
}

function Test-ScriptSyntax {
    param($scriptPath)
    $syntaxErrors = $null
    [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath), [ref]$syntaxErrors)
    return $syntaxErrors.Count -eq 0
}

try {
    Write-Host "APIM Solution Package Validation`n" -ForegroundColor Cyan
    
    # Find latest package if not specified
    if (-not $packageFile) {
        $latestPackage = Get-ChildItem "apim-minimal-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestPackage) {
            $packageFile = $latestPackage.FullName
        }
        else {
            throw "No package file found"
        }
    }
    
    Write-Host "Testing package: $packageFile"
    
    # Create test directory
    if (Test-Path $testPath) {
        Remove-Item $testPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testPath -Force | Out-Null
    
    # Extract package
    Write-Host "`nExtracting package..." -ForegroundColor Cyan
    Expand-Archive -Path $packageFile -DestinationPath $testPath
    
    # Verify required files
    Write-Host "`nChecking required files..." -ForegroundColor Cyan
    $requiredFiles = @(
        @{ Path = "deploy.ps1"; Type = "Deployment" }
        @{ Path = "template.json"; Type = "Template" }
        @{ Path = "parameters.example.json"; Type = "Configuration" }
        @{ Path = "scripts\cleanup.ps1"; Type = "Utility" }
        @{ Path = "scripts\health-check.ps1"; Type = "Monitoring" }
        @{ Path = "scripts\monitor.ps1"; Type = "Monitoring" }
        @{ Path = "docs\README.md"; Type = "Documentation" }
        @{ Path = "version.json"; Type = "Metadata" }
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $testPath $file.Path
        if (Test-Path $filePath) {
            if ((Get-Content $filePath).Length -gt 0) {
                Write-TestResult "$($file.Type) ($($file.Path))" "PASS" "Present and not empty"
            }
            else {
                Write-TestResult "$($file.Type) ($($file.Path))" "FAIL" "File is empty"
            }
        }
        else {
            Write-TestResult "$($file.Type) ($($file.Path))" "FAIL" "File not found"
        }
    }
    
    # Verify PowerShell scripts
    Write-Host "`nValidating PowerShell scripts..." -ForegroundColor Cyan
    Get-ChildItem $testPath -Recurse -Include *.ps1 | ForEach-Object {
        if (Test-ScriptSyntax $_.FullName) {
            Write-TestResult $_.Name "PASS" "Syntax validation successful"
        }
        else {
            Write-TestResult $_.Name "FAIL" "Syntax errors found"
        }
    }
    
    # Check ARM template
    Write-Host "`nValidating ARM template..." -ForegroundColor Cyan
    $templatePath = Join-Path $testPath "template.json"
    if (Test-Path $templatePath) {
        try {
            $template = Get-Content $templatePath | ConvertFrom-Json
            if ($template.schema -and $template.contentVersion) {
                Write-TestResult "ARM Template" "PASS" "Valid JSON structure"
            }
            else {
                Write-TestResult "ARM Template" "FAIL" "Missing required properties"
            }
        }
        catch {
            Write-TestResult "ARM Template" "FAIL" "Invalid JSON: $_"
        }
    }
    
    # Verify documentation
    Write-Host "`nChecking documentation..." -ForegroundColor Cyan
    Get-ChildItem $testPath -Recurse -Include *.md | ForEach-Object {
        $content = Get-Content $_.FullName
        if ($content.Length -gt 10) {
            Write-TestResult $_.Name "PASS" "$($content.Length) lines"
        }
        else {
            Write-TestResult $_.Name "WARN" "Minimal content"
        }
    }
    
    # Check version information
    Write-Host "`nVerifying version info..." -ForegroundColor Cyan
    $versionPath = Join-Path $testPath "version.json"
    if (Test-Path $versionPath) {
        try {
            $versionInfo = Get-Content $versionPath | ConvertFrom-Json
            Write-TestResult "Version Info" "PASS" "Version: $($versionInfo.version)"
        }
        catch {
            Write-TestResult "Version Info" "FAIL" "Invalid version file"
        }
    }
    
    # Summary
    Write-Host "`nTest Summary:" -ForegroundColor Cyan
    Write-Host "  Passed: $($testResults.Pass)" -ForegroundColor Green
    Write-Host "  Failed: $($testResults.Fail)" -ForegroundColor Red
    Write-Host "  Warnings: $($testResults.Warnings)" -ForegroundColor Yellow
    
    if ($testResults.Fail -gt 0) {
        throw "Package validation failed with $($testResults.Fail) errors"
    }
}
catch {
    Write-Error "Package validation failed: $_"
    exit 1
}
finally {
    if ($cleanup -and (Test-Path $testPath)) {
        Remove-Item $testPath -Recurse -Force
    }
}