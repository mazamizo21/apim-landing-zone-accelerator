param(
    [Parameter(Mandatory=$true)]
    [string]$name,
    
    [Parameter(Mandatory=$false)]
    [string]$logPath = ".\logs",
    
    [Parameter(Mandatory=$false)]
    [int]$retentionDays = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$sendEmail,
    
    [Parameter(Mandatory=$false)]
    [string]$emailTo,
    
    [Parameter(Mandatory=$false)]
    [string]$emailFrom
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'

# Ensure log directory exists
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Setup logging
$logFile = Join-Path $logPath "apim-monitor-$name-$timestamp.log"
Start-Transcript -Path $logFile

function Write-MonitorLog {
    param($message, $type = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')|$type|$message"
    Write-Host $logMessage
}

function Send-AlertEmail {
    param($subject, $body)
    if ($sendEmail -and $emailTo -and $emailFrom) {
        try {
            $params = @{
                From = $emailFrom
                To = $emailTo
                Subject = $subject
                Body = $body
                SmtpServer = "smtp.office365.com"
                Port = 587
                UseSSL = $true
            }
            Send-MailMessage @params
            Write-MonitorLog "Alert email sent to $emailTo" "INFO"
        }
        catch {
            Write-MonitorLog "Failed to send alert email: $_" "ERROR"
        }
    }
}

try {
    Write-MonitorLog "Starting APIM monitoring for: $name" "INFO"
    
    # Run health check
    $healthCheckOutput = & "$PSScriptRoot\health-check.ps1" -name $name -detailed -exportReport
    
    # Parse health check results
    $healthReport = Get-Content ".\health-check-$name-*.json" | Sort-Object -Descending | Select-Object -First 1 | ConvertFrom-Json
    
    # Check for critical issues
    $criticalIssues = @()
    
    if ($healthReport.Status.Overall -eq "Unhealthy") {
        $criticalIssues += "APIM service is unhealthy"
    }
    
    foreach ($component in $healthReport.Status.Components.GetEnumerator()) {
        if ($component.Value -eq "Unhealthy") {
            $criticalIssues += "Component $($component.Key) is unhealthy"
        }
    }
    
    # Alert on critical issues
    if ($criticalIssues.Count -gt 0) {
        $alertSubject = "CRITICAL: APIM $name has issues"
        $alertBody = "The following issues were detected:`n`n"
        $alertBody += $criticalIssues | ForEach-Object { "- $_`n" }
        $alertBody += "`nPlease check the health report for details."
        
        Send-AlertEmail -subject $alertSubject -body $alertBody
        Write-MonitorLog "Critical issues detected and alert sent" "WARNING"
    }
    
    # Clean up old logs
    $cutoffDate = (Get-Date).AddDays(-$retentionDays)
    Get-ChildItem -Path $logPath -Filter "apim-monitor-$name-*.log" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-MonitorLog "Cleaned up old log: $($_.Name)" "INFO"
        }
    
    # Clean up old health reports
    Get-ChildItem -Path "." -Filter "health-check-$name-*.json" |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-MonitorLog "Cleaned up old health report: $($_.Name)" "INFO"
        }
        
    Write-MonitorLog "Monitoring completed successfully" "INFO"
}
catch {
    Write-MonitorLog "Monitoring failed: $_" "ERROR"
    Send-AlertEmail -subject "ERROR: APIM Monitoring Failed" -body $_.Exception.Message
    throw $_
}
finally {
    Stop-Transcript
}

# Example scheduling command:
<#
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -name `"your-apim-name`""
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "APIM-Monitor" -Description "Monitor APIM health"
#>