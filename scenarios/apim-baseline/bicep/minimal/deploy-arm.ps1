param(
    [Parameter(Mandatory=$false)]
    [string]$namePrefix = "apimdev$(Get-Random -Minimum 100 -Maximum 999)",
    [Parameter(Mandatory=$false)]
    [string]$location = "eastus"
)

$ErrorActionPreference = 'Stop'

Write-Host "Starting APIM deployment...`n"
Write-Host "Parameters:"
Write-Host "  Name Prefix: $namePrefix"
Write-Host "  Location: $location"

# ARM template content
$template = @'
{
    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "namePrefix": { "type": "string" },
        "location": { "type": "string" }
    },
    "variables": {
        "rgName": "[format('rg-{0}', parameters('namePrefix'))]"
    },
    "resources": [
        {
            "type": "Microsoft.Resources/resourceGroups",
            "apiVersion": "2021-04-01",
            "name": "[variables('rgName')]",
            "location": "[parameters('location')]",
            "properties": {}
        },
        {
            "type": "Microsoft.Resources/deployments",
            "apiVersion": "2021-04-01",
            "name": "apimDeploy",
            "resourceGroup": "[variables('rgName')]",
            "dependsOn": [
                "[resourceId('Microsoft.Resources/resourceGroups', variables('rgName'))]"
            ],
            "properties": {
                "mode": "Incremental",
                "template": {
                    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "resources": [
                        {
                            "type": "Microsoft.Network/networkSecurityGroups",
                            "apiVersion": "2021-02-01",
                            "name": "[format('nsg-{0}', parameters('namePrefix'))]",
                            "location": "[parameters('location')]",
                            "properties": {
                                "securityRules": [
                                    {
                                        "name": "Management",
                                        "properties": {
                                            "priority": 100,
                                            "protocol": "Tcp",
                                            "access": "Allow",
                                            "direction": "Inbound",
                                            "sourceAddressPrefix": "ApiManagement",
                                            "sourcePortRange": "*",
                                            "destinationAddressPrefix": "VirtualNetwork",
                                            "destinationPortRange": "3443"
                                        }
                                    },
                                    {
                                        "name": "ClientComm",
                                        "properties": {
                                            "priority": 110,
                                            "protocol": "Tcp",
                                            "access": "Allow",
                                            "direction": "Inbound",
                                            "sourceAddressPrefix": "Internet",
                                            "sourcePortRange": "*",
                                            "destinationAddressPrefix": "VirtualNetwork",
                                            "destinationPortRange": "443"
                                        }
                                    }
                                ]
                            }
                        },
                        {
                            "type": "Microsoft.Network/virtualNetworks",
                            "apiVersion": "2021-02-01",
                            "name": "[format('vnet-{0}', parameters('namePrefix'))]",
                            "location": "[parameters('location')]",
                            "dependsOn": [
                                "[resourceId('Microsoft.Network/networkSecurityGroups', format('nsg-{0}', parameters('namePrefix')))]"
                            ],
                            "properties": {
                                "addressSpace": {
                                    "addressPrefixes": [
                                        "10.0.0.0/16"
                                    ]
                                },
                                "subnets": [
                                    {
                                        "name": "apim",
                                        "properties": {
                                            "addressPrefix": "10.0.1.0/24",
                                            "networkSecurityGroup": {
                                                "id": "[resourceId('Microsoft.Network/networkSecurityGroups', format('nsg-{0}', parameters('namePrefix')))]"
                                            }
                                        }
                                    }
                                ]
                            }
                        },
                        {
                            "type": "Microsoft.ApiManagement/service",
                            "apiVersion": "2021-08-01",
                            "name": "[format('apim-{0}', parameters('namePrefix'))]",
                            "location": "[parameters('location')]",
                            "dependsOn": [
                                "[resourceId('Microsoft.Network/virtualNetworks', format('vnet-{0}', parameters('namePrefix')))]"
                            ],
                            "sku": {
                                "name": "Developer",
                                "capacity": 1
                            },
                            "properties": {
                                "publisherEmail": "admin@contoso.com",
                                "publisherName": "Contoso API Management",
                                "virtualNetworkType": "Internal",
                                "virtualNetworkConfiguration": {
                                    "subnetResourceId": "[resourceId('Microsoft.Network/virtualNetworks/subnets', format('vnet-{0}', parameters('namePrefix')), 'apim')]"
                                }
                            }
                        }
                    ]
                }
            }
        }
    ],
    "outputs": {
        "apimName": {
            "type": "string",
            "value": "[format('apim-{0}', parameters('namePrefix'))]"
        },
        "resourceGroupName": {
            "type": "string",
            "value": "[variables('rgName')]"
        }
    }
}
'@

# Create temporary template file
$tempFile = Join-Path $env:TEMP "apim-template.json"
Set-Content -Path $tempFile -Value $template

try {
    Write-Host "`nStarting deployment..."
    $deployment = New-AzDeployment `
        -Name "apim-$(Get-Date -Format 'yyyyMMddHHmm')" `
        -Location $location `
        -TemplateFile $tempFile `
        -TemplateParameterObject @{
            namePrefix = $namePrefix
            location = $location
        } `
        -Verbose

    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        
        $rgName = $deployment.Outputs.resourceGroupName.Value
        $apimName = $deployment.Outputs.apimName.Value
        
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name $apimName
            Write-Host "`nAPIM Service Information:"
            Write-Host "  Gateway URL: $($apim.GatewayUrl)"
            Write-Host "  Portal URL: $($apim.PortalUrl)"
            Write-Host "  Management URL: $($apim.ManagementApiUrl)"
        }
        catch {
            Write-Warning "Could not retrieve APIM information. The service may still be provisioning."
            Write-Warning "Check the Azure portal for status and details."
        }
    }
    else {
        Write-Error "Deployment failed with status: $($deployment.ProvisioningState)"
        exit 1
    }
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    # Clean up temporary file
    if (Test-Path $tempFile) {
        Remove-Item $tempFile
    }
}