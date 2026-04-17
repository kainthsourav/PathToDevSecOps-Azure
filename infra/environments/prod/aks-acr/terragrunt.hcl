# infra/environments/prod/aks-acr/terragrunt.hcl
# MOVED from: infra/environments/prod/terragrunt.hcl
# Content unchanged

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/aks-acr"   # ← one extra ../ because now one level deeper
}

inputs = {
  resource_group_name = "rg-demoapi-prod"
  acr_name            = "acrdemosouravprod"
  aks_cluster_name    = "aks-dotnet-demo-prod"
  aks_node_count      = 1
  aks_node_size       = "Standard_B2s"
  environment         = "prod"
}