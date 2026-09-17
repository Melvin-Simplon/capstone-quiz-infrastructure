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

  # The state lived in a storage account inside the resource group it described,
  # and went with it when that group was emptied. Nothing recreated it, because
  # nothing could: it has to exist before the first init. Here it outlives the
  # environment entirely. See ADR 0013.
  #
  # The workspace runs in local execution mode: Terraform still runs on the
  # runner, and this holds nothing but the state, its versions and its lock.
  # Remote execution would run it on HashiCorp infrastructure, at an address
  # scripts/keyvault-firewall.sh cannot open, and every plan reading a secret
  # from the vault would fail.
  cloud {
    organization = "WhiteMuush-Organizations"

    workspaces {
      name = "simplon-quiz-nonprod"
    }
  }
}
