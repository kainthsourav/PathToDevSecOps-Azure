# infra/environments/staging/functions/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

dependency "aks_acr" {
  config_path = "../aks-acr"

  mock_outputs = {
    resource_group_name = "mock-rg"
    location            = "denmarkeast"
  }
  mock_outputs_allowed_plan_commands = ["validate", "plan"]
}

terraform {
  source = "../../../modules/functions"
}

inputs = {
  resource_group_name = dependency.aks_acr.outputs.resource_group_name
  location            = dependency.aks_acr.outputs.location

  storage_account_name  = "stfuncssouravstaging"
  app_service_plan_name = "asp-demoapi-staging"
  function_app_name     = "func-demoapi-staging"
  environment           = "staging"
}