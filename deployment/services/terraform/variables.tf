variable "deployment_local" {
  type        = bool
  description = "true for local desktop stack; false for cloud stack."
  default     = true
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for all Scoutify services."
  default     = "scoutify"
}

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  type        = string
  default     = "minikube"
}

variable "jwt_signing_key" {
  type        = string
  sensitive   = true
  description = "Shared JWT signing key for auth/stocks/features APIs."
}

variable "google_client_id" {
  type        = string
  default     = "PLACEHOLDER-GOOGLE-CLIENT-ID"
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = "PLACEHOLDER-OPENAI-KEY"
}

variable "alphavantage_api_key" {
  type      = string
  sensitive = true
  default   = "PLACEHOLDER-ALPHA-VANTAGE-KEY"
}

variable "finnhub_api_key" {
  type      = string
  sensitive = true
  default   = "PLACEHOLDER-FINNHUB-KEY"
}

variable "key_vault_uri" {
  type    = string
  default = "https://REPLACE-KEYVAULT-NAME.vault.azure.net/"
}

variable "service_bus_connection_string" {
  type      = string
  sensitive = true
  default   = "Endpoint=sb://REPLACE.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=REPLACE"
}

variable "local_vault_address" {
  type    = string
  default = "http://vault.scoutify.svc.cluster.local:8200"
}

variable "local_vault_root_token" {
  type      = string
  sensitive = true
  default   = "root"
}

variable "scoutify_api_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify:latest"
}

variable "auth_api_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify-auth-api:latest"
}

variable "features_api_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify-features-api:latest"
}

variable "stocks_api_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify-core-api:latest"
}

variable "edge_gateway_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify-edge-gateway:latest"
}

variable "ai_worker_image" {
  type    = string
  default = "ghcr.io/sushanth262/scoutify-ai-analysis-service:latest"
}
