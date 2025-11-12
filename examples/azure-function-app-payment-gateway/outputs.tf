output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.resource_group.resource_id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.main.default_hostname
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the Function App managed identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.key_vault.resource_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.uri
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = module.storage_account.resource_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = module.application_insights.name
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = module.application_insights.resource_id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.application_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.application_insights.connection_string
  sensitive   = true
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.log_analytics.resource.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.log_analytics.resource_id
}

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "function_subnet_id" {
  description = "ID of the function app subnet"
  value       = azurerm_subnet.function_subnet.id
}

output "deployment_instructions" {
  description = "Post-deployment instructions"
  value = <<-EOT
    
    ====================================
    Deployment Complete!
    ====================================
    
    Next Steps:
    
    1. Update Stripe API secrets in Key Vault:
       az keyvault secret set --vault-name ${module.key_vault.name} --name stripe-api-key --value "your-stripe-api-key"
       az keyvault secret set --vault-name ${module.key_vault.name} --name stripe-webhook-secret --value "your-stripe-webhook-secret"
    
    2. Deploy Function App code:
       func azure functionapp publish ${azurerm_linux_function_app.main.name}
    
    3. Access Application Insights:
       https://portal.azure.com/#resource${module.application_insights.resource_id}
    
    4. Function App URL:
       https://${azurerm_linux_function_app.main.default_hostname}
    
    5. Verify VNet Integration:
       az functionapp vnet-integration list --name ${azurerm_linux_function_app.main.name} --resource-group ${module.resource_group.name}
    
    ====================================
  EOT
}
