include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/aks-acr"
}

inputs = {
  resource_group_name = "rg-demoapi-dev"
  acr_name            = "acrdemosouravdev"
  aks_cluster_name    = "aks-dotnet-demo-dev"
  aks_node_count      = 1
  aks_node_size       = "Standard_B2s"
  environment         = "dev"
}