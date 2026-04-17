# infra/modules/functions/variable.tf

variable "resource_group_name" {
  description = "Resource group where Functions infrastructure is deployed — must already exist, created by aks-acr module"
  type        = string
}

variable "location" {
  description = "Azure region — must match aks-acr location"
  type        = string
  default     = "denmarkeast"
}

variable "environment" {
  description = "dev | staging | prod — controls storage replication type and app settings"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account for Durable Functions state, queues and history. Must be globally unique, 3-24 chars, lowercase letters and numbers only — no hyphens"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the Consumption App Service Plan (Y1 SKU)"
  type        = string
}

variable "function_app_name" {
  description = "Name of the Function App — must be globally unique across Azure"
  type        = string
}