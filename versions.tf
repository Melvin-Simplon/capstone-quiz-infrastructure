terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # use_azuread_auth: the state storage account has allow_shared_key_access = false,
  # so access goes through the Azure AD identity (az login locally, OIDC in CI).
  # No storage key is ever handled or stored.
  backend "azurerm" {
    resource_group_name  = "mpetitRG"
    storage_account_name = "sttfstatempetit"
    container_name       = "tfstate"
    key                  = "nonprod.terraform.tfstate"
    use_azuread_auth     = true
  }
}
