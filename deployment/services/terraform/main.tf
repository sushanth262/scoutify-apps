locals {
  rabbitmq_connection_string = "amqp://admin:admin123@rabbitmq.${var.namespace}.svc.cluster.local:5672/"
  redis_connection_string    = "redis.${var.namespace}.svc.cluster.local:6379"
  stocks_api_base_url        = "http://scoutify-stocks-api.${var.namespace}.svc.cluster.local:8080"
}

resource "kubernetes_namespace" "scoutify" {
  metadata {
    name = var.namespace
    labels = {
      app        = "scoutify"
      managed_by = "terraform"
    }
  }
}

resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "scoutify-app-secrets"
    namespace = kubernetes_namespace.scoutify.metadata[0].name
  }
  type = "Opaque"
  data = {
    JWT__SIGNINGKEY               = var.jwt_signing_key
    GOOGLE_CLIENT_ID              = var.google_client_id
    OPENAI_API_KEY                = var.openai_api_key
    ALPHA_VANTAGE_API_KEY         = var.alphavantage_api_key
    FINNHUB_API_KEY               = var.finnhub_api_key
    SERVICE_BUS_CONNECTION_STRING = var.service_bus_connection_string
    LOCAL_VAULT__VAULT_ROOT_TOKEN = var.local_vault_root_token
  }
}

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "scoutify-app-config"
    namespace = kubernetes_namespace.scoutify.metadata[0].name
  }
  data = {
    ASPNETCORE_URLS            = "http://+:8080"
    REQUEST_QUEUE              = "stock-requests"
    RESPONSE_QUEUE             = "stock-responses"
    SERVICE_BUS_REQUEST_QUEUE  = "stock-requests"
    SERVICE_BUS_RESPONSE_QUEUE = "stock-responses"
    StocksApi__BaseUrl         = local.stocks_api_base_url
    StocksApi__CardSymbols__0  = "AAPL"
    StocksApi__CardSymbols__1  = "MSFT"
    StocksApi__CardSymbols__2  = "TSLA"
    StocksApi__MaxCards        = "3"
    KEYVAULT_VAULT_URL         = var.deployment_local ? "local://" : var.key_vault_uri
    LOCAL_VAULT__VAULT_ADDRESS = var.local_vault_address
    RABBITMQ_CONNECTION_STRING = local.rabbitmq_connection_string
    Redis__ConnectionString    = local.redis_connection_string
  }
}

resource "kubernetes_deployment" "local_infra" {
  for_each = var.deployment_local ? {
    rabbitmq = { image = "rabbitmq:3-management-alpine", port = 5672 }
    redis    = { image = "redis:7-alpine", port = 6379 }
    vault    = { image = "hashicorp/vault:1.15", port = 8200 }
  } : {}

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.scoutify.metadata[0].name
    labels = { app = each.key }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = each.key } }
    template {
      metadata { labels = { app = each.key } }
      spec {
        container {
          name  = each.key
          image = each.value.image
          port { container_port = each.value.port }
          args = each.key == "vault" ? ["server", "-dev", "-dev-root-token-id=root"] : null
          dynamic "env" {
            for_each = each.key == "vault" ? [
              { name = "VAULT_DEV_ROOT_TOKEN_ID", value = "root" },
              { name = "VAULT_DEV_LISTEN_ADDRESS", value = "0.0.0.0:8200" }
            ] : each.key == "rabbitmq" ? [
              { name = "RABBITMQ_DEFAULT_USER", value = "admin" },
              { name = "RABBITMQ_DEFAULT_PASS", value = "admin123" }
            ] : []
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "local_infra" {
  for_each = var.deployment_local ? kubernetes_deployment.local_infra : {}

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.scoutify.metadata[0].name
  }
  spec {
    selector = { app = each.key }
    port {
      port        = each.key == "rabbitmq" ? 5672 : each.key == "redis" ? 6379 : 8200
      target_port = each.key == "rabbitmq" ? 5672 : each.key == "redis" ? 6379 : 8200
    }
  }
}

resource "kubernetes_deployment" "services" {
  for_each = {
    scoutify-auth-api     = { image = var.auth_api_image, port = 8080 }
    scoutify-features-api = { image = var.features_api_image, port = 8080 }
    scoutify-stocks-api   = { image = var.stocks_api_image, port = 8080 }
    scoutify-edge-gateway = { image = var.edge_gateway_image, port = 8080 }
    ai-analysis-worker    = { image = var.ai_worker_image, port = null }
    scoutify-ui-host      = { image = var.scoutify_api_image, port = 5000 }
  }

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.scoutify.metadata[0].name
    labels = { app = each.key }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = each.key } }
    template {
      metadata { labels = { app = each.key } }
      spec {
        container {
          name  = each.key
          image = each.value.image
          dynamic "port" {
            for_each = each.value.port == null ? [] : [each.value.port]
            content { container_port = port.value }
          }
          env_from {
            config_map_ref { name = kubernetes_config_map.app_config.metadata[0].name }
          }
          env_from {
            secret_ref { name = kubernetes_secret.app_secrets.metadata[0].name }
          }
          dynamic "env" {
            for_each = each.key == "scoutify-stocks-api" ? [
              { name = "Messaging__ConnectionString", value = var.deployment_local ? "" : var.service_bus_connection_string },
              { name = "Messaging__RabbitMqConnectionString", value = local.rabbitmq_connection_string }
            ] : each.key == "ai-analysis-worker" ? [
              { name = "SERVICE_BUS_CONNECTION_STRING", value = var.deployment_local ? "" : var.service_bus_connection_string },
              { name = "REQUEST_QUEUE", value = "stock-requests" },
              { name = "RESPONSE_QUEUE", value = "stock-responses" }
            ] : each.key == "scoutify-ui-host" ? [
              { name = "DOTNET_EDGE_GATEWAY_URL", value = "http://scoutify-edge-gateway.${var.namespace}.svc.cluster.local:8080" }
            ] : []
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "services" {
  for_each = {
    scoutify-auth-api     = { port = 8080, type = "ClusterIP" }
    scoutify-features-api = { port = 8080, type = "ClusterIP" }
    scoutify-stocks-api   = { port = 8080, type = "ClusterIP" }
    scoutify-edge-gateway = { port = 8080, type = "LoadBalancer" }
    scoutify-ui-host      = { port = 5000, type = "LoadBalancer" }
  }

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.scoutify.metadata[0].name
  }
  spec {
    selector = { app = each.key }
    port {
      port        = each.value.port
      target_port = each.value.port
    }
    type = each.value.type
  }
}
