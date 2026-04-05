#include root terragrunt.hcl
include "root"{
    path= find_in_parent_folders()
}

#point to terraform modules
terraform{
    source="../../modules/aks-acr"
}

# prod specific values
inputs={
    resource_group_name="rg-demoapi-prod"
    acr_name="acrdemosouravprod"
    aks_cluster_name="aks-dotnet-demo-prod"
    aks_node_count=3
    aks_node_size="Standard_D4d_v4"
    environment="prod"
}