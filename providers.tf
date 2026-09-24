provider "azurerm" {
  subscription_id = var.subscription_id

  # The storage account has no shared key to authenticate with, so any data plane
  # call has to carry the Azure AD identity instead.
  storage_use_azuread = true

  features {
    storage {
      # That account is also closed to the internet, which the runner is not part
      # of. Left at its default, the provider polls the blob endpoint right after
      # creating an account and fails there, even though the account itself is
      # fine. Everything this configuration needs from storage goes through the
      # Resource Manager API anyway, container included.
      data_plane_available = false
    }

    # See ADR 0014. Neither the pipeline nor the environment's owner holds the
    # subscription scoped right a purge needs, so destroy does not ask for one.
    # Recovery is off because a recovered vault comes back with its old
    # secrets, which the state no longer knows and refuses to overwrite.
    key_vault {
      purge_soft_delete_on_destroy          = false
      purge_soft_deleted_secrets_on_destroy = false
      recover_soft_deleted_key_vaults       = false
    }
  }
}
