param(
    [Parameter(Mandatory=$false)]
    [string]$version = "1.0.0",
    [Parameter(Mandatory=$false)]
    [string]$outputPath = ".\package"
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

function Write-PackageStatus {
    param($message, $type = "INFO")
    $color = switch($type) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Cyan" }
    }
    Write-Host "[$type] $message" -ForegroundColor $color
}

try {
    Write-PackageStatus "Creating APIM deployment package v$version" "INFO"
    
    # Create package directory
    if (Test-Path $outputPath) {
        Remove-Item $outputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputPath | Out-Null
    
    # Required files
    $files = @(
        # Deployment
        @{ Source = "deploy-min.ps1"; Target = "deploy.ps1" }
        @{ Source = "deploy-min.json"; Target = "template.json" }
        @{ Source = "parameters.example.json"; Target = "parameters.example.json" }
        
        # Scripts
        @{ Source = "cleanup.ps1"; Target = "scripts\cleanup.ps1" }
        @{ Source = "health-check.ps1"; Target = "scripts\health-check.ps1" }
        @{ Source = "monitor.ps1"; Target = "scripts\monitor.ps1" }
        @{ Source = "verify-config.ps1"; Target = "scripts\verify-config.ps1" }
        @{ Source = "test-solution.ps1"; Target = "scripts\test-solution.ps1" }
        
        # Documentation
        @{ Source = "README.md"; Target = "docs\README.md" }
        @{ Source = "QUICKSTART.md"; Target = "docs\QUICKSTART.md" }
        @{ Source = "MAINTENANCE.md"; Target = "docs\MAINTENANCE.md" }
        @{ Source = "TROUBLESHOOTING.md"; Target = "docs\TROUBLESHOOTING.md" }
        @{ Source = "CHECKLIST.md"; Target = "docs\CHECKLIST.md" }
        @{ Source = "SUMMARY.md"; Target = "docs\SUMMARY.md" }
    )
    
    # Create directory structure
    New-Item -ItemType Directory -Path "$outputPath\scripts" | Out-Null
    New-Item -ItemType Directory -Path "$outputPath\docs" | Out-Null
    
    # Copy files
    foreach ($file in $files) {
        if (Test-Path $file.Source) {
            $targetPath = Join-Path $outputPath $file.Target
            $targetDir = Split-Path $targetPath
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir | Out-Null
            }
            Copy-Item $file.Source $targetPath
            Write-PackageStatus "Copied $($file.Source) to $($file.Target)" "SUCCESS"
        }
        else {
            Write-PackageStatus "Missing file: $($file.Source)" "WARNING"
        }
    }
    
    # Create version file
    @{
        version = $version
        timestamp = Get-Date -Format 'o'
        files = $files | ForEach-Object { $_.Target }
    } | ConvertTo-Json | Set-Content "$outputPath\version.json"
    
    # Create package manifest
    @"
# APIM Minimal Deployment Package
Version: $version
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Directory Structure
- deploy.ps1 - Main deployment script
- template.json - ARM template
- parameters.example.json - Parameter examples
- scripts/ - Utility scripts
- docs/ - Documentation

## Quick Start
1. Copy parameters.example.json to parameters.json
2. Modify parameters as needed
3. Run deploy.ps1

## Requirements
- Azure PowerShell
- Azure subscription
- Contributor access

## Support
See docs/TROUBLESHOOTING.md for help
"@ | Set-Content "$outputPath\README.txt"
    
    # Create archive
    $archiveName = "apim-minimal-v$version-$timestamp.zip"
    Compress-Archive -Path "$outputPath\*" -DestinationPath $archiveName
    
    Write-PackageStatus "Package created successfully: $archiveName" "SUCCESS"
    Write-PackageStatus "Contents:"
    Get-ChildItem $outputPath -Recurse | Where-Object { -not $_.PSIsContainer } | 
        Select-Object @{N='File';E={$_.FullName.Replace($outputPath, '').TrimStart('\')}} | 
        Format-Table -AutoSize
        
    # Cleanup
    Remove-Item $outputPath -Recurse -Force
    
    Write-PackageStatus "Package size: $([math]::Round((Get-Item $archiveName).Length / 1KB, 2)) KB" "INFO"
}
catch {
    Write-PackageStatus "Failed to create package: $_" "ERROR"
    if (Test-Path $outputPath) {
        Remove-Item $outputPath -Recurse -Force
    }
    exit 1
}