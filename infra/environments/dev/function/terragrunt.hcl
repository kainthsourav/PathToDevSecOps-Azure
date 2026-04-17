# infra/environments/dev/functions/terragrunt.hcl

include "root" {
  path = find_in_parent_folders()
}

# ── DEPENDENCY ────────────────────────────────────────────────────────────────
# Tells Terragrunt: run aks-acr first, then pass its outputs here.
# This guarantees the RG exists before any resource in this module runs.
# Without this, if someone runs this manually before aks-acr,
# Terraform would fail trying to create resources in a non-existent RG.
dependency "aks_acr" {
  config_path = "../aks-acr"   # sibling folder — same level as this functions/ folder

  # mock_outputs are used during terragrunt validate and plan
  # when the real dependency has not been deployed yet.
  # Without mocks, plan fails because it cannot read real outputs from Azure.
  # Same concept as a stub in unit testing — fake values just to let the plan run.
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
  # Read from aks-acr outputs — not hardcoded
  # This is the dependency block paying off:
  # if someone renames the RG in aks-acr terragrunt.hcl,
  # this picks it up automatically on next apply
  resource_group_name = dependency.aks_acr.outputs.resource_group_name
  location            = dependency.aks_acr.outputs.location

  # Functions-specific values — unique per environment
  storage_account_name  = "stfuncssouravdev"   # globally unique, no hyphens
  app_service_plan_name = "asp-demoapi-dev"
  function_app_name     = "func-demoapi-dev"
  environment           = "dev"
}