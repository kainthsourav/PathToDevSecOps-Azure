terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
       version = "~> 4.0"
    }
  }

  backend "azurerm" {
    use_azuread_auth = true  # uses SP identity — no storage keys needed
  }
}

provider "azurerm" {
  features {}
}
