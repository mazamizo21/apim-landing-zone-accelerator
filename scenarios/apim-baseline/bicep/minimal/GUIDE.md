# Step-by-Step APIM Deployment Guide

This guide walks through the complete process of deploying and validating an API Management instance using our minimal deployment solution.

## Pre-Deployment Checklist

1. Verify Azure Requirements:
   ```powershell
   # Check PowerShell version
   $PSVersionTable.PSVersion
   
   # Check Az module
   Get-InstalledModule -Name Az
   
   # Connect to Azure
   Connect-AzAccount
   
   # Select subscription
   Set-AzContext -Subscription "Your-Subscription-Name"
   ```

2. Verify Network Requirements:
   - Available address space for VNET (10.0.0.0/16)
   - No conflicts with existing VNETs
   - Required ports (443, 3443) not blocked

## Deployment Steps

1. **Prepare Parameters**
   ```powershell
   $deploymentParams = @{
       name = "myapim"              # Base name for resources
       location = "eastus"          # Azure region
   }
   ```

2. **Initial Validation**
   ```powershell
   # Test template
   Test-AzDeployment `
       -Location $deploymentParams.location `
       -TemplateFile ".\deploy-basic.json" `
       -TemplateParameterObject $deploymentParams
   ```

3. **Execute Deployment**
   ```powershell
   # Run deployment
   ./deploy.ps1 @deploymentParams -Verbose
   ```

4. **Monitor Progress**
   - Initial deployment: ~10 minutes
   - APIM provisioning: ~40 minutes
   ```powershell
   # Check status
   ./validate.ps1 -name $deploymentParams.name
   ```

## Post-Deployment Tasks

1. **Validate Resources**
   ```powershell
   # Run detailed validation
   ./validate.ps1 -name $deploymentParams.name -detailed
   ```

2. **Verify Networking**
   - Check NSG rules
   - Verify subnet configuration
   - Test connectivity (when applicable)

3. **APIM Configuration**
   - Access management portal
   - Check API endpoints
   - Verify virtual network integration

## Common Issues and Solutions

### 1. Deployment Failures
```powershell
# Check resource group deployments
Get-AzResourceGroupDeployment -ResourceGroupName "rg-$($deploymentParams.name)"

# Get detailed error messages
(Get-AzResourceGroupDeployment -ResourceGroupName "rg-$($deploymentParams.name)" -Name "deployment-name").Error
```

### 2. Network Connectivity
```powershell
# Verify NSG rules
Get-AzNetworkSecurityGroup -ResourceGroupName "rg-$($deploymentParams.name)" | 
    Select-Object -ExpandProperty SecurityRules

# Check subnet configuration
Get-AzVirtualNetwork -ResourceGroupName "rg-$($deploymentParams.name)" |
    Select-Object -ExpandProperty Subnets
```

### 3. APIM Issues
```powershell
# Get APIM status
Get-AzApiManagement -ResourceGroupName "rg-$($deploymentParams.name)" -Name "apim-$($deploymentParams.name)"

# Check gateway health
$apim = Get-AzApiManagement -ResourceGroupName "rg-$($deploymentParams.name)" -Name "apim-$($deploymentParams.name)"
$apim.GatewayRegionalUrl
```

## Clean Up

1. **Backup Configuration (Optional)**
   ```powershell
   # Export APIM configuration
   Backup-AzApiManagement -ResourceGroupName "rg-$($deploymentParams.name)" `
       -Name "apim-$($deploymentParams.name)" `
       -StorageContext $storageContext `
       -ContainerName "backup" `
       -BlobName "apim-backup.bak"
   ```

2. **Remove Resources**
   ```powershell
   # Clean up with confirmation
   ./cleanup.ps1 -name $deploymentParams.name
   
   # Force clean up
   ./cleanup.ps1 -name $deploymentParams.name -force
   ```

## Monitoring and Maintenance

1. **Regular Health Checks**
   ```powershell
   # Daily validation
   ./validate.ps1 -name $deploymentParams.name -detailed
   ```

2. **Performance Monitoring**
   - Check API response times
   - Monitor capacity metrics
   - Review error rates

3. **Security Updates**
   - Check NSG rules regularly
   - Update API policies as needed
   - Review access controls

## Support and Troubleshooting

For issues or questions:
1. Check Azure Portal for detailed status
2. Review deployment logs
3. Run validation script with -detailed flag
4. Check [Azure Status](https://status.azure.com)

## Next Steps

1. Configure custom domain names
2. Set up monitoring and alerts
3. Implement API policies
4. Configure OAuth or other security
5. Set up CI/CD pipelines

## Additional Resources

- [APIM Documentation](https://docs.microsoft.com/azure/api-management/)
- [Networking Guide](https://docs.microsoft.com/azure/api-management/api-management-using-with-vnet)
- [Best Practices](https://docs.microsoft.com/azure/api-management/api-management-howto-best-practices)
- [Troubleshooting Guide](https://docs.microsoft.com/azure/api-management/api-management-troubleshoot-issues)