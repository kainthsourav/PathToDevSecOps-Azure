# Remote state configuration for Terraform using Azure Blob Storage
remote_state {
  backend = "azurerm"

  # Generate backend.tf file automatically
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  # Backend settings: where Terraform state will be stored
  config = {
    resource_group_name   = "rg-terraform-state"     # RG holding the storage account
    storage_account_name  = "tfstatesouravdemo"      # Storage account name
    container_name        = "tfstate"                # Blob container for state
    key                   = "${path_relative_to_include()}/terraform.tfstate" # Unique key per module
    use_azuread_auth     = false
  }
}

# Generate provider.tf file automatically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
    terraform {
      required_version = ">= 1.3.0"

      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 4.0"   # Using v4 provider (matches lock file)
        }
      }

      # Backend block is generated above by Terragrunt
    }

    provider "azurerm" {
      features {}
    }
EOF
}

# Input variables passed to modules
inputs = {
  location   = "eastasia"     # Azure region
  managed_by = "terragrunt"   # Tagging / metadata
}