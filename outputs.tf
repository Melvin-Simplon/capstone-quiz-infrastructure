output "backend_url" {
  description = "Public URL of the backend"
  value       = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "frontend_url" {
  description = "Public URL of the application"
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
}

output "backend_app_name" {
  description = "Web App name, used by the backend pipeline to deploy the jar"
  value       = azurerm_linux_web_app.backend.name
}

output "static_web_app_name" {
  description = "Static Web App name, used by the frontend pipeline"
  value       = azurerm_static_web_app.frontend.name
}

output "key_vault_name" {
  description = "Vault holding the database password, the Redis key and the API key"
  value       = azurerm_key_vault.main.name
}

output "postgres_fqdn" {
  description = "Private name of the database server, resolvable from the network only"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "storage_account_name" {
  description = "Storage account backing the quiz result uploads"
  value       = azurerm_storage_account.main.name
}
