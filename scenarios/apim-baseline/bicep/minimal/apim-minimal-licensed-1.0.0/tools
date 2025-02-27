param(
    [Parameter(Mandatory=$false)]
    [string]$packagePath,
    [Parameter(Mandatory=$false)]
    [string]$verifyPath = ".\verify-release",
    [Parameter(Mandatory=$false)]
    [switch]$cleanup
)

$ErrorActionPreference = 'Stop'
$requiredComponents = @{
    src = @(
        'deploy-min.json',
        'version.json'
    )
    scripts = @(
        'deploy-min.ps1',
        'cleanup.ps1',
        'health-check.ps1',
        'monitor.ps1',
        'verify-config.ps1'
    )
    tools = @(
        'test-solution.ps1',
        'test-package.ps1',
        'create-package.ps1'
    )
    docs = @(
        'README.md',
        'QUICKSTART.md',
        'MAINTENANCE.md',
        'TROUBLESHOOTING.md',
        'CHECKLIST.md',
        'CHANGELOG.md',
        'VERIFICATION.md',
        'RELEASE_NOTES.md'
    )
    examples = @(
        'parameters.example.json'
    )
}

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

function Test-PackageStructure {
    param($path)
    $results = @{
        Pass = 0
        Fail = 0
        Missing = @()
    }

    foreach ($dir in $requiredComponents.Keys) {
        $dirPath = Join-Path $path $dir
        if (Test-Path $dirPath) {
            Write-Status "Checking $dir directory..." "INFO"
            foreach ($file in $requiredComponents[$dir]) {
                $filePath = Join-Path $dirPath $file
                if (Test-Path $filePath) {
                    $content = Get-Content $filePath
                    if ($content) {
                        Write-Status "  $file - Present and contains content" "SUCCESS"
                        $results.Pass++
                    }
                    else {
                        Write-Status "  $file - Empty file" "WARNING"
                        $results.Missing += "$dir\$file (empty)"
                        $results.Fail++
                    }
                }
                else {
                    Write-Status "  $file - Missing" "ERROR"
                    $results.Missing += "$dir\$file"
                    $results.Fail++
                }
            }
        }
        else {
            Write-Status "$dir directory missing" "ERROR"
            $results.Fail++
        }
    }

    return $results
}

function Test-ScriptSyntax {
    param($path)
    $results = @{
        Pass = 0
        Fail = 0
        Errors = @()
    }

    Get-ChildItem -Path $path -Recurse -Filter "*.ps1" | ForEach-Object {
        Write-Status "Checking syntax: $($_.Name)" "INFO"
        $syntaxErrors = $null
        [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName), [ref]$syntaxErrors)
        
        if ($syntaxErrors) {
            Write-Status "  Syntax errors found in $($_.Name)" "ERROR"
            $results.Fail++
            $results.Errors += $_.Name
        }
        else {
            Write-Status "  Syntax valid" "SUCCESS"
            $results.Pass++
        }
    }

    return $results
}

try {
    Write-Host "APIM Production Release Verification`n" -ForegroundColor Cyan
    
    # Find latest package if not specified
    if (-not $packagePath) {
        $latestPackage = Get-ChildItem "apim-minimal-production-*.zip" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        if ($latestPackage) {
            $packagePath = $latestPackage.FullName
        }
        else {
            throw "No production package found"
        }
    }
    
    Write-Host "Verifying package: $packagePath`n"
    
    # Extract package
    if (Test-Path $verifyPath) {
        Remove-Item $verifyPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $verifyPath -Force | Out-Null
    
    Write-Status "Extracting package..." "INFO"
    Expand-Archive -Path $packagePath -DestinationPath $verifyPath
    
    # Check structure
    Write-Host "`nVerifying package structure..." -ForegroundColor Cyan
    $structureResults = Test-PackageStructure $verifyPath
    
    # Check scripts
    Write-Host "`nVerifying scripts..." -ForegroundColor Cyan
    $scriptResults = Test-ScriptSyntax $verifyPath
    
    # Summary
    Write-Host "`nVerification Summary:" -ForegroundColor Cyan
    Write-Host "Package Structure:"
    Write-Host "  Passed: $($structureResults.Pass)" -ForegroundColor Green
    Write-Host "  Failed: $($structureResults.Fail)" -ForegroundColor Red
    
    if ($structureResults.Missing) {
        Write-Host "`nMissing or Empty Components:" -ForegroundColor Yellow
        $structureResults.Missing | ForEach-Object {
            Write-Host "  - $_"
        }
    }
    
    Write-Host "`nScript Validation:"
    Write-Host "  Passed: $($scriptResults.Pass)" -ForegroundColor Green
    Write-Host "  Failed: $($scriptResults.Fail)" -ForegroundColor Red
    
    if ($scriptResults.Errors) {
        Write-Host "`nScript Errors:" -ForegroundColor Red
        $scriptResults.Errors | ForEach-Object {
            Write-Host "  - $_"
        }
    }
    
    # Final status
    $totalFailed = $structureResults.Fail + $scriptResults.Fail
    if ($totalFailed -eq 0) {
        Write-Host "`nFinal Result: PASSED" -ForegroundColor Green
        Write-Host "Package is ready for production use."
    }
    else {
        Write-Host "`nFinal Result: FAILED" -ForegroundColor Red
        Write-Host "Package requires attention before release."
        throw "Verification failed with $totalFailed issues"
    }
}
finally {
    if ($cleanup -and (Test-Path $verifyPath)) {
        Remove-Item $verifyPath -Recurse -Force
    }
}