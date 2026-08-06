resource "random_password" "backend_api_key" {
  length  = 48
  special = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Role assignments rather than access policies: the same RBAC model as every
  # other resource here, and it can be scoped to a single secret if ever needed.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  # Left off deliberately: the training subscription cannot purge a protected
  # vault, so a rebuild would collide with the soft-deleted name for 90 days.
  purge_protection_enabled = false

  # Kept reachable, unlike the storage account, because secrets are written over
  # the data plane and the firewall below is what actually restricts it.
  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    # Lets Azure services that authenticate with a managed identity through, which
    # is how App Service resolves the @Microsoft.KeyVault references.
    bypass = "AzureServices"
    # Empty, and left alone afterwards: whoever runs Terraform has to read these
    # secrets over the data plane, and gets a different address on every run. An
    # address that changes each time is not desired state, so scripts/keyvault-
    # firewall.sh opens the door for the run and closes it after. Holding the
    # list here instead deadlocks the refresh: Terraform would have to read the
    # secrets before it could grant itself the right to read them.
    ip_rules = []
  }

  tags = merge(local.common_tags, { component = "secrets" })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [network_acls[0].ip_rules]
  }
}

# Terraform's own identity: Contributor on the resource group is a control plane
# role and grants nothing on secrets, so writing them requires this.
resource "azurerm_role_assignment" "deployer_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = azurerm_managed_redis.main.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets]

  lifecycle {
    prevent_destroy = true
  }
}

# Generated here rather than handed over by anyone: the frontend reads it back
# from the vault at deploy time and inlines it in its build.
resource "azurerm_key_vault_secret" "backend_api_key" {
  name         = "backend-api-key"
  value        = random_password.backend_api_key.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets]

  lifecycle {
    prevent_destroy = true
  }
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
