locals {
  common_tags = {
    owner       = var.owner
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }

  name_suffix = "${var.project}-${var.owner}"

  storage_account_name = replace("st${local.name_suffix}", "-", "")

  key_vault_name = replace("kv${local.name_suffix}${random_string.key_vault.result}", "-", "")

  storage_container_name = "java-uploads-${var.owner}"

  frontend_origin = "https://${azurerm_static_web_app.frontend.default_host_name}"
}
