resource "azurerm_storage_account" "main" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # No shared key means no connection string to leak: the backend authenticates
  # with its managed identity, and so does Terraform.
  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Fully closed to the internet, reached only through the private endpoint below.
  # Affordable here because the container is created over the control plane, which
  # this switch does not filter.
  public_network_access_enabled = false

  # Redundant with the line above, which already denies everything: an account
  # closed to the internet has no traffic left for these rules to sort. Kept
  # because it is what an audit reads, and because it is what still stands if
  # public access is ever turned back on.
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "uploads" {
  name                  = local.storage_container_name
  container_access_type = "private"

  # storage_account_id, not storage_account_name: the id form goes through the
  # Resource Manager API, the name form through the blob data plane, which the
  # account firewall blocks.
  storage_account_id = azurerm_storage_account.main.id

  lifecycle {
    prevent_destroy = true
  }
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

# Scoped to the single container rather than the account: the backend writes quiz
# results and has no business reading anything else stored here later.
resource "azurerm_role_assignment" "backend_blob" {
  scope                = azurerm_storage_container.uploads.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}
