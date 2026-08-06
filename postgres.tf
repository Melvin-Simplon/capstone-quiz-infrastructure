resource "random_password" "postgres_admin" {
  length = 32
  # Azure rejects '/', '\' and '"' in the administrator password, and the JDBC URL
  # carries it, so the allowed set is narrowed rather than left to the default.
  override_special = "!#%*()-_=+[]{}:?"
}

# Private access (VNet injection) instead of a private endpoint: the server gets
# no public endpoint at all, so there is no public surface left to filter. See
# decision 18 on the board.
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

  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  # Not redundant with the injection: the argument defaults to true, and the
  # provider requires it to be false as soon as a delegated subnet is used.
  public_network_access_enabled = false

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  # The server resolves its own name through the zone, so the link has to exist
  # before it is created, and the dependency is not visible through the ids above.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  tags = merge(local.common_tags, { component = "database" })

  lifecycle {
    prevent_destroy = true
  }
}

# Created empty on purpose: the schema and its data come from the Flyway
# migrations shipped with the backend, which run at application startup.
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}
