terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3"
    }
  }
  backend "azurerm" {
    resource_group_name  = "base"
    storage_account_name = "tkubicastore"
    container_name       = "tfstate"
    key                  = "longintro.iac.tfstate"
    subscription_id      = "d3b7888f-c26e-4961-a976-ff9d5b31dfd3"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    use_oidc = true
  }
}
