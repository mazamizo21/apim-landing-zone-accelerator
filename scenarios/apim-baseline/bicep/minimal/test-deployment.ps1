param(
    [Parameter(Mandatory=$false)]
    [string]$name = "apimtest$(Get-Random -Minimum 1000 -Maximum 9999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus",
    [Parameter(Mandatory=$false)]
    [switch]$cleanup
)

$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

function Write-Status {
    param($message, $type = "Info")
    
    $color = switch ($type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        default   { "White" }
    }
    
    Write-Host "[$type] $message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Status "PowerShell 7+ recommended (current: $($PSVersionTable.PSVersion))" "Warning"
    }
    
    # Check Az module
    try {
        Import-Module Az -ErrorAction Stop
        Write-Status "Az module loaded successfully" "Success"
    }
    catch {
        Write-Status "Az module not found or failed to load" "Error"
        exit 1
    }
    
    # Check Azure connection
    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context) { throw "No Azure context" }
        Write-Status "Connected to Azure subscription: $($context.Subscription.Name)" "Success"
    }
    catch {
        Write-Status "Not connected to Azure. Run Connect-AzAccount first" "Error"
        exit 1
    }
    
    # Check required files
    $requiredFiles = @(
        'deploy-basic.json',
        'deploy.ps1',
        'validate.ps1',
        'cleanup.ps1'
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path (Join-Path $baseDir $file))) {
            Write-Status "Required file not found: $file" "Error"
            exit 1
        }
    }
    Write-Status "All required files present" "Success"
}

function Test-Deployment {
    Write-Status "Starting test deployment for: $name"
    
    try {
        # Deploy APIM
        Write-Status "Deploying APIM resources..."
        & "$baseDir\deploy.ps1" -name $name -location $location
        if ($LASTEXITCODE -ne 0) { throw "Deployment failed" }
        
        # Wait for initial provisioning
        Write-Status "Waiting 60 seconds for initial provisioning..."
        Start-Sleep -Seconds 60
        
        # Validate deployment
        Write-Status "Validating deployment..."
        & "$baseDir\validate.ps1" -name $name -detailed
        if ($LASTEXITCODE -ne 0) { throw "Validation failed" }
        
        Write-Status "Deployment test completed successfully" "Success"
    }
    catch {
        Write-Status "Deployment test failed: $_" "Error"
        if ($cleanup) {
            Write-Status "Cleaning up failed deployment..."
            & "$baseDir\cleanup.ps1" -name $name -force
        }
        exit 1
    }
}

function Test-Cleanup {
    if ($cleanup) {
        Write-Status "Testing cleanup process..."
        try {
            & "$baseDir\cleanup.ps1" -name $name -force
            Write-Status "Cleanup completed successfully" "Success"
        }
        catch {
            Write-Status "Cleanup failed: $_" "Error"
            exit 1
        }
    }
    else {
        Write-Status "Skipping cleanup (use -cleanup to test cleanup process)" "Warning"
    }
}

# Main test sequence
try {
    Write-Status "Starting deployment test sequence" "Info"
    Write-Status "Test Configuration:" "Info"
    Write-Status "  Name: $name" "Info"
    Write-Status "  Location: $location" "Info"
    Write-Status "  Cleanup: $cleanup" "Info"
    
    Test-Prerequisites
    Test-Deployment
    Test-Cleanup
    
    Write-Status "Test sequence completed successfully" "Success"
}
catch {
    Write-Status "Test sequence failed: $_" "Error"
    exit 1
}