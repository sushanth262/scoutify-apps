output "namespace" {
  value       = kubernetes_namespace.scoutify.metadata[0].name
  description = "Namespace where Scoutify services are deployed."
}

output "mode" {
  value       = var.deployment_local ? "local" : "cloud"
  description = "Effective deployment mode."
}

output "ui_service_name" {
  value       = kubernetes_service.services["scoutify-ui-host"].metadata[0].name
  description = "Kubernetes service name for Scoutify UI host."
}

output "edge_gateway_service_name" {
  value       = kubernetes_service.services["scoutify-edge-gateway"].metadata[0].name
  description = "Kubernetes service name for edge gateway."
}
