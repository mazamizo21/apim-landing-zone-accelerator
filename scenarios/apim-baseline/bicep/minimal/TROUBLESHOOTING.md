# APIM Deployment Troubleshooting Guide

## Common Issues and Solutions

### 1. Deployment Failures

#### Permission Issues
```text
Error: The client does not have permission to perform action
```
**Solution:**
1. Verify Azure role assignments
2. Ensure you have Contributor access
3. Check resource provider registration
```powershell
# Check role assignments
Get-AzRoleAssignment

# Register required providers
Register-AzResourceProvider -ProviderNamespace "Microsoft.ApiManagement"
Register-AzResourceProvider -ProviderNamespace "Microsoft.Network"
```

#### Network Conflicts
```text
Error: Subnet ... conflicts with existing subnet
```
**Solution:**
1. Check VNET address space
2. Verify subnet availability
```powershell
# List existing VNETs
Get-AzVirtualNetwork | Select-Object Name, AddressSpace

# Modify deployment parameters for different address space
.\deploy-min.ps1 -name "myapim" -location "eastus"
```

### 2. APIM Provisioning Issues

#### Long Provisioning Times
```text
Status: Creating... (40+ minutes)
```
**Solution:**
- APIM typically takes 30-45 minutes
- Use health check to monitor:
```powershell
.\health-check.ps1 -name <apim-name> -detailed
```

#### Failed Provisioning
```text
Error: Provisioning failed
```
**Solution:**
1. Check activity logs
2. Verify network settings
3. Try cleanup and redeploy
```powershell
# Clean up failed deployment
.\cleanup.ps1 -name <apim-name> -force

# Redeploy
.\deploy-min.ps1 -name <apim-name> -location "eastus"
```

### 3. Network Connectivity

#### NSG Issues
```text
Error: Network security group does not allow access
```
**Solution:**
1. Verify NSG rules
2. Check required ports (443, 3443)
```powershell
# Get NSG rules
Get-AzNetworkSecurityGroup -ResourceGroupName "rg-<name>" | 
    Select-Object -ExpandProperty SecurityRules
```

#### VNET Integration
```text
Error: Failed to connect to VNET
```
**Solution:**
1. Check subnet delegation
2. Verify address space
3. Ensure NSG association
```powershell
# Validate VNET config
Get-AzVirtualNetwork -ResourceGroupName "rg-<name>" | 
    Select-Object -ExpandProperty Subnets
```

### 4. Validation Failures

#### Script Errors
```text
Error: Script execution failed
```
**Solution:**
1. Check PowerShell version
2. Verify Azure module
3. Run with verbose logging
```powershell
# Check environment
$PSVersionTable.PSVersion
Get-InstalledModule Az

# Run with verbose
.\deploy-min.ps1 -name <apim-name> -Verbose
```

#### Resource Validation
```text
Error: Resource validation failed
```
**Solution:**
1. Run verification script
2. Check resource quotas
3. Verify naming conventions
```powershell
# Validate deployment
.\verify-config.ps1 -name <apim-name> -detailed
```

### 5. Monitoring Issues

#### Log Collection
```text
Error: Cannot collect logs
```
**Solution:**
1. Check permissions
2. Verify log path
3. Enable verbose logging
```powershell
# Run monitoring with debug
.\monitor.ps1 -name <apim-name> -logPath .\logs -Verbose
```

#### Alert Configuration
```text
Error: Failed to send alerts
```
**Solution:**
1. Verify email settings
2. Check SMTP configuration
3. Test alert system
```powershell
# Test monitoring
.\monitor.ps1 -name <apim-name> -sendEmail -emailTo "admin@contoso.com"
```

## Quick Recovery Steps

### 1. Full Redeployment
```powershell
# 1. Clean up
.\cleanup.ps1 -name <apim-name> -force

# 2. Wait 5 minutes for resource cleanup
Start-Sleep -Seconds 300

# 3. Redeploy
.\deploy-min.ps1 -name <apim-name> -location "eastus"

# 4. Verify
.\verify-config.ps1 -name <apim-name> -detailed
```

### 2. Network Recovery
```powershell
# 1. Verify NSG
Get-AzNetworkSecurityGroup -ResourceGroupName "rg-<name>"

# 2. Check VNET
Get-AzVirtualNetwork -ResourceGroupName "rg-<name>"

# 3. Validate connectivity
Test-NetConnection -ComputerName "apim-<name>.azure-api.net" -Port 443
```

### 3. Health Check
```powershell
# 1. Run health check
.\health-check.ps1 -name <apim-name> -detailed

# 2. Export report
.\verify-config.ps1 -name <apim-name> -exportReport

# 3. Review logs
Get-Content .\logs\*.log | Select-String "ERROR"
```

## Support Resources

1. Azure Documentation
   - [APIM Troubleshooting](https://docs.microsoft.com/azure/api-management/api-management-troubleshoot)
   - [Network Configuration](https://docs.microsoft.com/azure/api-management/api-management-using-with-vnet)

2. Log Collection
   ```powershell
   # Collect all logs
   Get-ChildItem .\logs\* | Compress-Archive -DestinationPath "apim-logs.zip"
   ```

3. Health Report
   ```powershell
   # Generate full health report
   .\health-check.ps1 -name <apim-name> -detailed -exportReport