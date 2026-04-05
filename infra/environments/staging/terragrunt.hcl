#include root terragrunt.hcl
include "root"{
    path= find_in_parent_folders()
}

#point to terraform modules
terraform{
    source="../../modules/aks-acr"
}

# staging specific values
inputs={
    resource_group_name="rg-demoapi-staging"
    acr_name="acrdemosouravstaging"
    aks_cluster_name="aks-dotnet-demo-staging"
    aks_node_count=2
    aks_node_size="Standard_B2s"
    environment="staging"
}