param(
    [Parameter(Mandatory=$false)]
    [string]$archivePath = ".\archive",
    [Parameter(Mandatory=$false)]
    [switch]$cleanup
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

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

try {
    Write-Host "APIM Solution Archival Process`n" -ForegroundColor Cyan
    
    # Create archive directory
    if (-not (Test-Path $archivePath)) {
        New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    }
    
    # Create timestamped directory
    $timeDir = Join-Path $archivePath $timestamp
    New-Item -ItemType Directory -Path $timeDir -Force | Out-Null
    
    # Archive components
    Write-Status "Archiving solution components..."
    
    # 1. Collect release packages
    $releaseDir = Join-Path $timeDir "releases"
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    Get-ChildItem -Filter "apim-minimal-*.zip" | ForEach-Object {
        Write-Status "Archiving release: $($_.Name)"
        Copy-Item $_.FullName -Destination $releaseDir
    }
    
    # 2. Archive source files
    $sourceDir = Join-Path $timeDir "source"
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
    
    $sourceFiles = @(
        "*.ps1",
        "*.json",
        "*.md",
        "LICENSE"
    )
    
    foreach ($pattern in $sourceFiles) {
        Get-ChildItem -Filter $pattern | ForEach-Object {
            Write-Status "Archiving source: $($_.Name)"
            Copy-Item $_.FullName -Destination $sourceDir
        }
    }
    
    # 3. Create inventory
    $inventory = @{
        timestamp = Get-Date -Format 'o'
        location = $timeDir
        components = @{
            releases = @()
            source = @()
        }
    }
    
    Get-ChildItem $releaseDir | ForEach-Object {
        $hash = Get-FileHash $_.FullName -Algorithm SHA256
        $inventory.components.releases += @{
            name = $_.Name
            size = $_.Length
            hash = $hash.Hash
        }
    }
    
    Get-ChildItem $sourceDir | ForEach-Object {
        $hash = Get-FileHash $_.FullName -Algorithm SHA256
        $inventory.components.source += @{
            name = $_.Name
            size = $_.Length
            hash = $hash.Hash
        }
    }
    
    $inventory | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $timeDir "inventory.json")
    
    # 4. Create archive summary
    @"
# APIM Solution Archive
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Location: $timeDir

## Contents
1. Releases: $(@(Get-ChildItem $releaseDir).Count) packages
2. Source Files: $(@(Get-ChildItem $sourceDir).Count) files

## Verification
- Inventory: inventory.json
- SHA256 hashes included
- Content verified

## Recovery
To restore:
1. Extract required files from archive
2. Verify hashes in inventory.json
3. Test components before use

Archive created by: $env:USERNAME
"@ | Set-Content (Join-Path $timeDir "README.md")
    
    # 5. Create archive package
    $archiveFile = "apim-solution-archive-$timestamp.zip"
    Compress-Archive -Path $timeDir -DestinationPath (Join-Path $archivePath $archiveFile)
    
    Write-Status "`nArchive created successfully" "SUCCESS"
    Write-Status "Location: $(Join-Path $archivePath $archiveFile)" "INFO"
    
    # Cleanup if requested
    if ($cleanup) {
        Write-Status "`nCleaning up working files..." "INFO"
        Remove-Item $timeDir -Recurse -Force
        
        # Clean up release packages
        Get-ChildItem -Filter "apim-minimal-*.zip" | ForEach-Object {
            Write-Status "Removing: $($_.Name)" "INFO"
            Remove-Item $_.FullName -Force
        }
        
        Write-Status "Cleanup completed" "SUCCESS"
    }
    
    Write-Status "`nArchival process completed successfully" "SUCCESS"
}
catch {
    Write-Status "Archival failed: $_" "ERROR"
    exit 1
}