resource "azurerm_managed_redis" "main" {
  name                = "redis-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  sku_name = var.redis_sku_name

  high_availability_enabled = true

  public_network_access = "Disabled"

  default_database {
    client_protocol = "Encrypted"

    access_keys_authentication_enabled = true

    clustering_policy = "EnterpriseCluster"
    eviction_policy   = "VolatileLRU"
  }

  tags = merge(local.common_tags, { component = "cache" })
}

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_managed_redis.main.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = merge(local.common_tags, { component = "cache" })
}
