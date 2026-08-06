# Azure Managed Redis (ARM type Microsoft.Cache/redisEnterprise), not Azure Cache
# for Redis: creation of the older product is closed on this subscription.
# azurerm_redis_enterprise_cluster covers the same ARM type but is deprecated and
# disappears in provider v5, and it cannot turn the public endpoint off.
resource "azurerm_managed_redis" "main" {
  name                = "redis-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  sku_name = var.redis_sku_name

  # Left on, as on every other Balanced_B0 already running in this subscription.
  # Turning it off would suit a cache holding only recomputable data, but nothing
  # here proves the smallest SKU accepts it and a failed apply costs more than the
  # second node.
  high_availability_enabled = true

  public_network_access = "Disabled"

  default_database {
    client_protocol = "Encrypted"

    # Defaults to false, which leaves Entra ID as the only way in. Spring Data
    # Redis authenticates with a password here, and that password is the access
    # key, so turning this off would leave the backend unable to connect.
    access_keys_authentication_enabled = true

    # EnterpriseCluster exposes a single endpoint that plain Redis clients can
    # reach; OSSCluster would require a cluster-aware client, which the backend's
    # Lettuce configuration is not.
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
