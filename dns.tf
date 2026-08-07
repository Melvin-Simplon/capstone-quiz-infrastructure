# One private DNS zone per service reached privately. Without them the public
# names of PostgreSQL, Redis, Storage and Key Vault keep resolving to their public
# addresses from inside the network, and the private endpoints are never used.
# Zone names are imposed by Azure, they are not a naming choice.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.name_suffix}.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.main.name

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                = "link-postgres"
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  virtual_network_id  = azurerm_virtual_network.main.id

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                = "link-redis"
  private_dns_zone_id = azurerm_private_dns_zone.redis.id
  virtual_network_id  = azurerm_virtual_network.main.id

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                = "link-blob"
  private_dns_zone_id = azurerm_private_dns_zone.blob.id
  virtual_network_id  = azurerm_virtual_network.main.id

  tags = merge(local.common_tags, { component = "network" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                = "link-keyvault"
  private_dns_zone_id = azurerm_private_dns_zone.keyvault.id
  virtual_network_id  = azurerm_virtual_network.main.id

  tags = merge(local.common_tags, { component = "network" })
}
