output "workspaceId" {
  description = "The id of the workspace"
  value       = azurerm_log_analytics_workspace.log_analytics_workspace.id
}

output "instrumentationKey" {
  description = "The instrumentation key of the workspace"
  value       = azurerm_application_insights.shared_apim_insight.instrumentation_key
}

output "keyVaultId" {
  value = azurerm_key_vault.key_vault.id
}