resource "random_password" "backend_api_key" {
  length  = 48
  special = false
}

resource "random_string" "key_vault" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = []
  }

  tags = merge(local.common_tags, { component = "secrets" })

  lifecycle {
    ignore_changes = [network_acls[0].ip_rules]

    precondition {
      condition     = length(local.key_vault_name) <= 24
      error_message = "The vault name ${local.key_vault_name} is over 24 characters: shorten var.owner or var.project."
    }
  }
}

resource "azurerm_role_assignment" "deployer_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_principal_id
}

resource "azurerm_role_assignment" "backend_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets]
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = azurerm_managed_redis.main.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets]
}

resource "azurerm_key_vault_secret" "backend_api_key" {
  name         = "backend-api-key"
  value        = random_password.backend_api_key.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets]
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = merge(local.common_tags, { component = "secrets" })
}
