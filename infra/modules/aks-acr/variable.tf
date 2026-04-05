variable "resource_group_name" {
  description = "Resource group for DemoApi infrastructure"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "denmarkeast"
}

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4d_v4"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}