terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatesouravdemo"
    container_name       = "tfstate"
    key                  = "demoapi.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}