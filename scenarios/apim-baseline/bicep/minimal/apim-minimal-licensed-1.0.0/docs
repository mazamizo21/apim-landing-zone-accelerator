# Minimal APIM Deployment Solution

A streamlined solution for deploying Azure API Management in internal networking mode with essential security configurations.

## Solution Components

### Deployment Files
- `deploy-basic.json` - Main ARM template for deployment
- `parameters.json` - Default parameters configuration
- `deploy.ps1` - Primary deployment script with validation
- `cleanup.ps1` - Resource cleanup utility
- `validate.ps1` - Deployment validation tool

## Prerequisites

- Azure PowerShell Az module (`Install-Module -Name Az`)
- Azure CLI (for template validation)
- Azure subscription with Contributor access
- PowerShell 7.0 or higher recommended

## Quick Start

1. Clone the repository and navigate to the minimal directory:
   ```powershell
   cd apim-landing-zone-accelerator/scenarios/apim-baseline/bicep/minimal
   ```

2. Deploy APIM with default settings:
   ```powershell
   ./deploy.ps1 -name "myapim" -location "eastus"
   ```

3. Validate the deployment:
   ```powershell
   ./validate.ps1 -name "myapim" -detailed
   ```

4. Clean up resources when done:
   ```powershell
   ./cleanup.ps1 -name "myapim"
   ```

## Deployment Features

- Single resource group deployment
- Internal VNET integration
- NSG with required security rules
- Developer SKU for cost optimization
- Basic network isolation

### Network Configuration
- VNET: 10.0.0.0/16
- APIM Subnet: 10.0.1.0/24
- NSG Rules:
  - Management (3443)
  - Gateway (443)

## Script Details

### deploy.ps1
- Validates Azure context
- Performs template validation
- Handles deployment with progress monitoring
- Provides deployment outputs

### validate.ps1
- Verifies resource creation
- Checks network configuration
- Validates APIM service status
- Reports detailed configuration (optional)

### cleanup.ps1
- Safe resource removal
- Confirmation prompt (unless -force used)
- Resource listing before deletion
- Clean error handling

## Parameters

### Common Parameters
- `name`: Base name for all resources
- `location`: Azure region for deployment
- `environment`: (parameters.json) Environment configuration

### Validation Options
- `-detailed`: Show extended configuration details
- `-force`: Skip confirmation in cleanup

## Deployment Process

1. Resource Group Creation
2. Network Security Group Deployment
3. Virtual Network Setup
4. APIM Service Deployment

## Post-Deployment

1. Monitor APIM provisioning (40+ minutes)
2. Configure DNS for APIM endpoints
3. Set up network connectivity
4. Validate deployment with validate.ps1

## Security Features

- Internal network mode
- NSG protection
- Subnet isolation
- Network policy enforcement

## Troubleshooting

Common issues and solutions:
1. Deployment Timeout
   - APIM provisioning takes time
   - Use validate.ps1 to check status

2. Network Connectivity
   - Verify NSG rules
   - Check DNS configuration
   - Validate subnet configuration

3. Validation Errors
   - Check Azure context
   - Verify resource names
   - Review deployment logs

## Best Practices

1. Always run validation post-deployment
2. Use parameters.json for consistent configuration
3. Implement additional security as needed
4. Back up configuration before cleanup

## Additional Resources

- [Azure APIM Documentation](https://docs.microsoft.com/azure/api-management/)
- [VNET Integration Guide](https://docs.microsoft.com/azure/api-management/api-management-using-with-vnet)
- [NSG Configuration](https://docs.microsoft.com/azure/api-management/api-management-using-with-vnet#-required-ports)

## Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.