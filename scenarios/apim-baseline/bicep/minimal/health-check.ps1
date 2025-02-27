param(
    [Parameter(Mandatory=$true)]
    [string]$name,
    
    [Parameter(Mandatory=$false)]
    [switch]$detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$exportReport
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

function Write-HealthStatus {
    param($component, $status, $message)
    $color = switch($status) {
        "Healthy"   { "Green" }
        "Warning"   { "Yellow" }
        "Unhealthy" { "Red" }
        default     { "White" }
    }
    Write-Host "[$status] $component - $message" -ForegroundColor $color
}

function Test-ApimEndpoint {
    param($url)
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Method Head
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Get-ApimMetrics {
    param($resourceId)
    try {
        $metrics = Get-AzMetric -ResourceId $resourceId -MetricName @(
            'Capacity',
            'SuccessfulRequests',
            'FailedRequests',
            'TotalRequests',
            'Latency'
        ) -TimeGrain 00:05:00 -StartTime (Get-Date).AddHours(-1)
        return $metrics
    }
    catch {
        return $null
    }
}

try {
    $rgName = "rg-$name"
    $apimName = "apim-$name"
    
    Write-Host "Starting APIM health check for: $apimName`n"
    
    $results = @{
        Timestamp = Get-Date
        ApimName = $apimName
        Status = @{
            Overall = "Unknown"
            Components = @{}
        }
        Metrics = @{}
        Details = @{}
    }
    
    # Check APIM service
    try {
        $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName
        Write-HealthStatus "APIM Service" "Healthy" "Service found and accessible"
        $results.Status.Components.Service = "Healthy"
        
        # Check provisioning state
        if ($apim.ProvisioningState -eq "Succeeded") {
            Write-HealthStatus "Provisioning" "Healthy" "Fully provisioned"
            $results.Status.Components.Provisioning = "Healthy"
        }
        else {
            Write-HealthStatus "Provisioning" "Warning" "State: $($apim.ProvisioningState)"
            $results.Status.Components.Provisioning = "Warning"
        }
        
        # Check networking
        if ($apim.VirtualNetworkType -eq "Internal") {
            Write-HealthStatus "Network Mode" "Healthy" "Internal VNET mode configured"
            $results.Status.Components.NetworkMode = "Healthy"
        }
        else {
            Write-HealthStatus "Network Mode" "Warning" "Not in internal mode"
            $results.Status.Components.NetworkMode = "Warning"
        }
        
        # Check endpoints
        $endpoints = @{
            Gateway = $apim.GatewayUrl
            Portal = $apim.PortalUrl
            Management = $apim.ManagementApiUrl
        }
        
        foreach ($endpoint in $endpoints.GetEnumerator()) {
            if (Test-ApimEndpoint $endpoint.Value) {
                Write-HealthStatus "$($endpoint.Key) Endpoint" "Healthy" "Accessible"
                $results.Status.Components["$($endpoint.Key)Endpoint"] = "Healthy"
            }
            else {
                Write-HealthStatus "$($endpoint.Key) Endpoint" "Warning" "Not accessible"
                $results.Status.Components["$($endpoint.Key)Endpoint"] = "Warning"
            }
        }
        
        # Get metrics if detailed check requested
        if ($detailed) {
            Write-Host "`nCollecting detailed metrics..."
            $metrics = Get-ApimMetrics -resourceId $apim.Id
            if ($metrics) {
                $results.Metrics = $metrics
                Write-Host "Recent performance metrics:"
                foreach ($metric in $metrics) {
                    $latestValue = $metric.Data | Select-Object -Last 1
                    Write-Host "  $($metric.Name.Value): $($latestValue.Average)"
                }
            }
            
            # Check APIs
            $apis = Get-AzApiManagementApi -Context $apim
            Write-Host "`nAPI Status:"
            Write-Host "  Total APIs: $($apis.Count)"
            $results.Details.APIs = $apis.Count
        }
        
        # Set overall status
        $unhealthyComponents = $results.Status.Components.Values | Where-Object { $_ -eq "Unhealthy" }
        $warningComponents = $results.Status.Components.Values | Where-Object { $_ -eq "Warning" }
        
        if ($unhealthyComponents) {
            $results.Status.Overall = "Unhealthy"
        }
        elseif ($warningComponents) {
            $results.Status.Overall = "Warning"
        }
        else {
            $results.Status.Overall = "Healthy"
        }
    }
    catch {
        Write-HealthStatus "APIM Service" "Unhealthy" $_.Exception.Message
        $results.Status.Overall = "Unhealthy"
        $results.Status.Components.Service = "Unhealthy"
    }
    
    # Export report if requested
    if ($exportReport) {
        $reportPath = ".\health-check-$name-$timestamp.json"
        $results | ConvertTo-Json -Depth 10 | Set-Content $reportPath
        Write-Host "`nHealth check report exported to: $reportPath"
    }
    
    # Final status
    Write-Host "`nOverall Status: $($results.Status.Overall)"
    
    if ($results.Status.Overall -eq "Unhealthy") {
        exit 1
    }
}
catch {
    Write-HealthStatus "Health Check" "Unhealthy" $_.Exception.Message
    exit 1
}