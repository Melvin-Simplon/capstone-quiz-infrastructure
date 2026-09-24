resource "azurerm_storage_account" "main" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  public_network_access_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = merge(local.common_tags, { component = "storage" })
}

resource "azurerm_storage_container" "uploads" {
  name                  = local.storage_container_name
  container_access_type = "private"

  storage_account_id = azurerm_storage_account.main.id
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-blob-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = azurerm_subnet.privatelink.id

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = merge(local.common_tags, { component = "storage" })
}

resource "azurerm_role_assignment" "backend_blob" {
  scope                = azurerm_storage_container.uploads.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}
