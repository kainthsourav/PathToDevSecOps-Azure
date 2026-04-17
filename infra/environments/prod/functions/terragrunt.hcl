# infra/environments/prod/functions/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

# ── DEPENDENCY ────────────────────────────────────────────────────────────────
# Tells Terragrunt: run aks-acr first, then pass its outputs here.
# This guarantees the RG exists before any resource in this module runs.
# Without this, if someone runs this manually before aks-acr,
# Terraform would fail trying to create resources in a non-existent RG.
dependency "aks_acr" {
  config_path = "../aks-acr"

  # mock_outputs are used during init, validate and plan
  # when the real dependency has not been deployed yet.
  # Without mocks, these commands fail because they cannot
  # read real outputs from Azure.
  mock_outputs = {
    resource_group_name = "mock-rg"
    location            = "denmarkeast"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "../../../modules/functions"
}

inputs = {
  # Read from aks-acr outputs — not hardcoded
  # If someone renames the RG in aks-acr terragrunt.hcl,
  # this picks it up automatically on next apply
  resource_group_name = dependency.aks_acr.outputs.resource_group_name
  location            = dependency.aks_acr.outputs.location

  # Functions-specific values — unique to prod environment
  storage_account_name  = "stfuncssouravprod"
  app_service_plan_name = "asp-demoapi-prod"
  function_app_name     = "func-demoapi-prod"
  environment           = "prod"
}