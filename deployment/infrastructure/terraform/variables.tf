variable "deployment_local" {
  type        = bool
  description = "true for local desktop deployment, false for Azure cloud deployment."
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment name (dev, qa, prod)."
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region for cloud deployment."
  default     = "eastus"
}

variable "resource_group_name" {
  type        = string
  description = "Azure resource group name for cloud resources."
  default     = "scoutify-dev-rg"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used to generate Azure resource names."
  default     = "scoutify-dev"
}

variable "aks_kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version."
  default     = "1.29.7"
}

variable "aks_node_vm_size" {
  type        = string
  description = "AKS system node VM size."
  default     = "Standard_B2s"
}

variable "aks_node_count" {
  type        = number
  description = "AKS system node count."
  default     = 1
}

variable "service_bus_namespace_name" {
  type        = string
  description = "Service Bus namespace name."
  default     = "scoutify-dev-sb"
}

variable "key_vault_name" {
  type        = string
  description = "Azure Key Vault name."
  default     = "scoutifydevkv001"
}
