data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Shared across all trainees: referenced only, never created or modified here.
data "azurerm_service_plan" "shared" {
  name                = var.shared_service_plan_name
  resource_group_name = var.shared_resource_group_name
}
