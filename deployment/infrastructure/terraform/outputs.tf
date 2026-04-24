output "deployment_mode" {
  value       = var.deployment_local ? "local" : "cloud"
  description = "Indicates active deployment mode."
}

output "aks_resource_group" {
  value       = var.deployment_local ? null : azurerm_resource_group.scoutify[0].name
  description = "AKS resource group name."
}

output "aks_cluster_name" {
  value       = var.deployment_local ? null : azurerm_kubernetes_cluster.scoutify[0].name
  description = "AKS cluster name."
}

output "aks_kube_config" {
  value       = var.deployment_local ? null : azurerm_kubernetes_cluster.scoutify[0].kube_config_raw
  description = "Raw kubeconfig for AKS (sensitive)."
  sensitive   = true
}

output "service_bus_connection_string" {
  value       = var.deployment_local ? null : azurerm_servicebus_namespace.scoutify[0].default_primary_connection_string
  description = "Service Bus connection string."
  sensitive   = true
}

output "key_vault_uri" {
  value       = var.deployment_local ? null : azurerm_key_vault.scoutify[0].vault_uri
  description = "Azure Key Vault URI."
}
