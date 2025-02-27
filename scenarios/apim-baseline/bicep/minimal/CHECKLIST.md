# APIM Deployment Validation Checklist

## Pre-Deployment Checks

### Azure Environment
- [ ] Azure PowerShell module installed and updated
- [ ] Sufficient permissions in subscription
- [ ] Required resource providers registered
- [ ] Subscription quota available for APIM

### Network Requirements
- [ ] No VNET address space conflicts (10.0.0.0/16)
- [ ] Required ports available (443, 3443)
- [ ] No NSG conflicts in target region
- [ ] DNS resolution working properly

## Deployment Verification

### Resource Group
- [ ] Created successfully
- [ ] Correct location
- [ ] Proper naming convention
- [ ] Required tags applied

### Network Security Group
- [ ] Created successfully
- [ ] Management rule (3443) configured
- [ ] Client communication rule (443) configured
- [ ] No conflicting rules
- [ ] Attached to APIM subnet

### Virtual Network
- [ ] Created successfully
- [ ] Correct address space
- [ ] APIM subnet properly sized
- [ ] NSG association successful
- [ ] No overlapping address spaces
- [ ] Private endpoints enabled

### APIM Service
- [ ] Created successfully
- [ ] Internal VNET mode enabled
- [ ] Subnet association successful
- [ ] Developer SKU configured
- [ ] Publisher details set
- [ ] Gateway accessible
- [ ] Management endpoint accessible

## Post-Deployment Tests

### Network Connectivity
```powershell
# Test NSG
Get-AzNetworkSecurityGroup -ResourceGroupName "rg-{name}" -Name "nsg-{name}"

# Test VNET
Get-AzVirtualNetwork -ResourceGroupName "rg-{name}" -Name "vnet-{name}"

# Test APIM network status
Get-AzApiManagement -ResourceGroupName "rg-{name}" -Name "apim-{name}"
```

### APIM Functionality
- [ ] Gateway endpoint responding
- [ ] Portal endpoint accessible
- [ ] Management endpoint accessible
- [ ] Echo API deployed (if configured)
- [ ] Subscriptions working
- [ ] VNET integration confirmed

### Security Verification
- [ ] No public IP exposure
- [ ] NSG rules minimal and correct
- [ ] Private endpoints working
- [ ] Management endpoints secured
- [ ] Subscription keys rotatable

## Performance Checks
```powershell
# Check APIM metrics
Get-AzMetric -ResourceId "/subscriptions/{sub}/resourceGroups/rg-{name}/providers/Microsoft.ApiManagement/service/apim-{name}"

# Test latency
Test-NetConnection -ComputerName "apim-{name}.azure-api.net" -Port 443
```

## Monitoring Setup
- [ ] Diagnostics enabled
- [ ] Log Analytics configured
- [ ] Metrics collection working
- [ ] Alerts configured
- [ ] Health check API setup

## Documentation Tasks
- [ ] Network diagram updated
- [ ] DNS records documented
- [ ] Access procedures documented
- [ ] Emergency contacts updated
- [ ] Runbook created

## Recovery Verification
- [ ] Backup configured
- [ ] Restore tested
- [ ] DR procedures documented
- [ ] Scale procedures tested
- [ ] Rollback plan available

## Cleanup Verification
```powershell
# Test cleanup script
.\cleanup.ps1 -name {name} -WhatIf

# Verify resource locks
Get-AzResourceLock -ResourceGroupName "rg-{name}"
```

## Final Steps
1. Run full validation script:
   ```powershell
   .\verify-config.ps1 -name {name} -detailed -exportReport
   ```

2. Review validation report
3. Document any deviations
4. Update runbook with findings
5. Schedule regular health checks

## Regular Maintenance
- [ ] Weekly health checks scheduled
- [ ] Monthly security review planned
- [ ] Quarterly DR tests scheduled
- [ ] Annual certification review set
- [ ] Regular backup verification planned

## Notes
- Keep this checklist updated
- Document all exceptions
- Maintain change log
- Review regularly
- Update as needed