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
  }
}
