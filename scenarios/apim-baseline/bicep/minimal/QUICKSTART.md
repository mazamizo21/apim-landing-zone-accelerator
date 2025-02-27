# APIM Minimal Deployment - Quick Start Guide

## Overview
This solution provides a streamlined deployment of Azure API Management with essential networking and security configurations.

## Prerequisites
```powershell
# Install required modules
Install-Module -Name Az -Force
```

## Quick Deploy
```powershell
# Connect to Azure
Connect-AzAccount

# Deploy APIM
.\deploy-min.ps1 -name "myapim" -location "eastus"
```

## Solution Components

### Deployed Resources
- Resource Group (`rg-{name}`)
- Network Security Group (`nsg-{name}`)
- Virtual Network (`vnet-{name}`)
- API Management Service (`apim-{name}`)

### Network Configuration
- VNET: 10.0.0.0/16
- APIM Subnet: 10.0.1.0/24
- NSG Rules:
  - Management (3443)
  - Client Communication (443)

### APIM Configuration
- SKU: Developer
- Network Mode: Internal VNET
- Default APIs: None

## Deployment Options

### Basic Deployment
```powershell
.\deploy-min.ps1
```

### Custom Deployment
```powershell
.\deploy-min.ps1 -name "customapim" -location "westus2"
```

### Monitoring Deployment
```powershell
# Get deployment status
Get-AzResourceGroup -Name "rg-{name}" | 
    Get-AzResourceGroupDeployment

# Get APIM status
Get-AzApiManagement -ResourceGroupName "rg-{name}" -Name "apim-{name}"
```

## Post-Deployment

### 1. Access APIM
- Gateway URL: `https://apim-{name}.azure-api.net`
- Portal URL: `https://apim-{name}.portal.azure-api.net`
- Management URL: `https://apim-{name}.management.azure-api.net`

### 2. Configure DNS
```powershell
# Get APIM private IP
$apim = Get-AzApiManagement -ResourceGroupName "rg-{name}" -Name "apim-{name}"
$apim.PrivateIPAddresses[0]
```

### 3. Verify Network
```powershell
# Test network configuration
Get-AzVirtualNetwork -ResourceGroupName "rg-{name}" -Name "vnet-{name}"
```

## Troubleshooting

### Common Issues

1. Deployment Timeout
   ```powershell
   # Check provisioning state
   Get-AzApiManagement -ResourceGroupName "rg-{name}" -Name "apim-{name}"
   ```

2. Network Issues
   ```powershell
   # Verify NSG rules
   Get-AzNetworkSecurityGroup -ResourceGroupName "rg-{name}" -Name "nsg-{name}" |
       Select-Object -ExpandProperty SecurityRules
   ```

3. Connectivity Problems
   ```powershell
   # Check VNET configuration
   Get-AzVirtualNetwork -ResourceGroupName "rg-{name}" -Name "vnet-{name}" |
       Select-Object -ExpandProperty Subnets
   ```

## Clean Up

### Remove Deployment
```powershell
# Remove resource group and all resources
Remove-AzResourceGroup -Name "rg-{name}" -Force
```

## Additional Notes

1. **Provisioning Time**
   - Full APIM provisioning can take up to 40 minutes
   - Network configuration applies immediately

2. **Security**
   - Deployed in internal VNET mode
   - NSG restricts access to required ports
   - No public IP by default

3. **Monitoring**
   - Use Azure Portal for detailed status
   - Check resource health after deployment
   - Monitor NSG flow logs for network issues

## Next Steps

1. Configure custom domains
2. Add APIs and products
3. Set up monitoring
4. Configure authentication
5. Implement caching

## Support

For issues:
1. Check Azure Portal
2. Review deployment logs
3. Verify network configuration
4. Check [Azure Status](https://status.azure.com)