# infra/modules/functions/output.tf

output "function_app_name" {
  description = "Function App name — used in pipeline for 'az functionapp deployment' command"
  value       = azurerm_linux_function_app.functions.name
}

output "function_app_hostname" {
  description = "Default hostname — used to call function HTTP endpoints from pipeline"
  value       = azurerm_linux_function_app.functions.default_hostname
  # Example: func-demoapi-dev.azurewebsites.net
  # Your pipeline posts to: https://{hostname}/api/scan/start
}

output "function_app_identity_principal_id" {
  description = "Managed identity principal ID — use for additional role assignments if needed"
  value       = azurerm_linux_function_app.functions.identity[0].principal_id
}

output "storage_account_name" {
  description = "Storage account holding all Durable Functions orchestration state"
  value       = azurerm_storage_account.functions.name
}

output "storage_connection_string" {
  description = "Storage connection string — sensitive, never printed in logs"
  value       = azurerm_storage_account.functions.primary_connection_string
  sensitive   = true
  # Same as kube_config in your aks-acr output.tf — sensitive = true
  # means Terraform will not print it in terminal or pipeline logs
}