#include root terragrunt.hcl
include "root"{
    path= find_in_parent_folders()
}

#point to terraform modules
terraform{
    source="../../modules/aks-acr"
}

# Dev specific values
inputs={
    resource_group_name="rg-demoapi-dev"
    acr_name="acrdemosouravdev"
    aks_cluster_name="aks-dotnet-demo-dev"
    aks_node_count=1
    aks_node_size="Standard_B2s"
    environment="dev"
}