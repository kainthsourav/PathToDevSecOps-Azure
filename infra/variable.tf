variable "resouce_group_name" {
  description = "Resource group name for demo api infra"
  type        = string
}

variable "location" {
  description = "Location for demo api infra"
  type        = string
}

variable "acr_name" {
  description = "ACR name for demo api infra"
  type        = string
}

variable "aks_name" {
  description = "AKS name for demo api infra"
  type        = string
}

variable "aks_node_count" {
  description = "AKS node count for demo api infra"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "AKS node size for demo api infra"
  type        = string
  default     = "Standard_D4d_v4"
}
variable "environment" {
  description = "Environment for demo api infra"
  type        = string
  default     = "dev"
}
variable "project" {
  description = "Project name for demo api infra"
  type        = string
  default     = "demo-api"
}
