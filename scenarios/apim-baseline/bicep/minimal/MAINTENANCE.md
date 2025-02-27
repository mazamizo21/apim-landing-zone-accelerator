# APIM Maintenance and Monitoring Guide

This guide covers the maintenance and monitoring tools provided with the minimal APIM deployment solution.

## Available Tools

### 1. Health Check Script
```powershell
.\health-check.ps1 -name <apim-name> [-detailed] [-exportReport]
```
- Performs comprehensive health check
- Validates all components
- Generates detailed report
- Supports JSON export

### 2. Monitoring Script
```powershell
.\monitor.ps1 -name <apim-name> [-logPath .\logs] [-retentionDays 30] [-sendEmail] [-emailTo user@domain.com] [-emailFrom sender@domain.com]
```
- Continuous monitoring
- Email alerts
- Log retention
- Automated cleanup

### 3. Validation Script
```powershell
.\verify-config.ps1 -name <apim-name> [-detailed] [-exportReport]
```
- Configuration verification
- Deployment validation
- Security checks
- Compliance reporting

## Regular Maintenance Tasks

### Daily
1. Run health checks:
   ```powershell
   .\health-check.ps1 -name <apim-name> -detailed
   ```

2. Monitor logs:
   ```powershell
   .\monitor.ps1 -name <apim-name> -logPath .\logs
   ```

3. Review alerts:
   - Check email notifications
   - Review Azure Monitor alerts
   - Verify Gateway health

### Weekly
1. Full configuration validation:
   ```powershell
   .\verify-config.ps1 -name <apim-name> -detailed -exportReport
   ```

2. Review performance:
   - Check metrics
   - Analyze traffic patterns
   - Verify capacity

3. Security review:
   - Check NSG rules
   - Verify network isolation
   - Review access logs

### Monthly
1. Comprehensive health report:
   ```powershell
   # Generate full report
   .\health-check.ps1 -name <apim-name> -detailed -exportReport
   
   # Review historical data
   Get-ChildItem .\logs\health-check-*.json | Sort-Object LastWriteTime -Descending
   ```

2. Policy review:
   - Check API policies
   - Validate security policies
   - Update as needed

3. Backup verification:
   - Verify backup status
   - Test restore procedures
   - Update DR documentation

## Automated Monitoring

### Schedule Health Checks
```powershell
# Create scheduled task for daily health check
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File `"$PWD\health-check.ps1`" -name <apim-name> -detailed -exportReport"
$trigger = New-ScheduledTaskTrigger -Daily -At "09:00"
Register-ScheduledTask -TaskName "APIM-HealthCheck" -Action $action -Trigger $trigger
```

### Configure Monitoring
```powershell
# Set up continuous monitoring
$monitorAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File `"$PWD\monitor.ps1`" -name <apim-name> -sendEmail -emailTo admin@contoso.com"
$monitorTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "APIM-Monitor" -Action $monitorAction -Trigger $monitorTrigger
```

## Alert Configuration

### Email Alerts
Configure in monitor.ps1:
```powershell
.\monitor.ps1 -name <apim-name> `
    -sendEmail `
    -emailTo "admin@contoso.com" `
    -emailFrom "apim-monitor@contoso.com"
```

### Azure Monitor
1. Set up metric alerts
2. Configure action groups
3. Define thresholds

## Log Management

### Log Locations
- Health check logs: `.\logs\health-check-*.log`
- Monitor logs: `.\logs\apim-monitor-*.log`
- Validation reports: `.\logs\verification-*.json`

### Retention Policy
Default: 30 days
```powershell
# Modify retention
.\monitor.ps1 -name <apim-name> -retentionDays 60
```

### Log Analysis
```powershell
# Get recent health checks
Get-Content .\logs\health-check-*.log | Select-String "WARNING|ERROR"

# Review monitoring history
Get-Content .\logs\apim-monitor-*.log | Where-Object { $_ -match (Get-Date).ToString("yyyy-MM-dd") }
```

## Troubleshooting

### Common Issues
1. Connectivity Problems
   ```powershell
   # Check network status
   .\health-check.ps1 -name <apim-name> -detailed
   ```

2. Performance Issues
   ```powershell
   # Review metrics
   Get-Content .\logs\apim-monitor-*.log | Select-String "Latency|Capacity"
   ```

3. Configuration Drift
   ```powershell
   # Validate configuration
   .\verify-config.ps1 -name <apim-name> -detailed
   ```

### Recovery Steps
1. Review latest health report
2. Check monitoring logs
3. Validate configuration
4. Apply necessary fixes
5. Verify resolution

## Best Practices

1. Regular Monitoring
   - Schedule daily health checks
   - Configure email alerts
   - Review logs regularly

2. Proactive Maintenance
   - Follow maintenance schedule
   - Keep documentation updated
   - Test recovery procedures

3. Security Updates
   - Review NSG rules monthly
   - Update policies as needed
   - Maintain access controls

4. Documentation
   - Keep runbooks current
   - Document all changes
   - Maintain incident logs