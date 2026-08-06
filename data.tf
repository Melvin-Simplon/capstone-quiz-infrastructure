data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# Shared with the whole promotion and owned by the trainer: referenced, never created.
data "azurerm_service_plan" "shared" {
  name                = var.app_service_plan_name
  resource_group_name = var.shared_resource_group_name
}
