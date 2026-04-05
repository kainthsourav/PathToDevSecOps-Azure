output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "ACR login server — use this in your pipeline instead of hardcoding"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "ACR name"
  value       = azurerm_container_registry.acr.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_resource_group" {
  description = "Resource group where AKS lives"
  value       = azurerm_resource_group.rg.name
}


# sensitive = true means Terraform won't print it in terminal logs
# but you can still reference it in pipelines
output "kube_config" {
  description = "Kubeconfig to connect kubectl to AKS"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}