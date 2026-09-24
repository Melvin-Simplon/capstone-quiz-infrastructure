provider "azurerm" {
  subscription_id = var.subscription_id

  storage_use_azuread = true

  features {
    storage {
      data_plane_available = false
    }

    key_vault {
      purge_soft_delete_on_destroy          = false
      purge_soft_deleted_secrets_on_destroy = false
      recover_soft_deleted_key_vaults       = false
    }
  }
}
