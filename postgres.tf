resource "random_password" "postgres_admin" {
  length           = 32
  override_special = "!#%*()-_=+[]{}:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  version    = var.postgres_version
  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb
  zone       = "1"

  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.postgres_admin.result

  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  tags = merge(local.common_tags, { component = "database" })
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
