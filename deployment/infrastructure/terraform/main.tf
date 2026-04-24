terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "scoutify" {
  count    = var.deployment_local ? 0 : 1
  name     = var.resource_group_name
  location = var.location

  tags = {
    app         = "scoutify"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "scoutify" {
  count               = var.deployment_local ? 0 : 1
  name                = "${var.name_prefix}-aks"
  location            = azurerm_resource_group.scoutify[0].location
  resource_group_name = azurerm_resource_group.scoutify[0].name
  dns_prefix          = "${var.name_prefix}-aks"
  kubernetes_version  = var.aks_kubernetes_version
  sku_tier            = "Free"

  default_node_pool {
    name                = "system"
    vm_size             = var.aks_node_vm_size
    node_count          = var.aks_node_count
    os_disk_size_gb     = 64
    orchestrator_version = var.aks_kubernetes_version
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    app         = "scoutify"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_servicebus_namespace" "scoutify" {
  count               = var.deployment_local ? 0 : 1
  name                = var.service_bus_namespace_name
  location            = azurerm_resource_group.scoutify[0].location
  resource_group_name = azurerm_resource_group.scoutify[0].name
  sku                 = "Basic"

  tags = {
    app         = "scoutify"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_servicebus_queue" "stock_requests" {
  count        = var.deployment_local ? 0 : 1
  name         = "stock-requests"
  namespace_id = azurerm_servicebus_namespace.scoutify[0].id
}

resource "azurerm_servicebus_queue" "stock_responses" {
  count        = var.deployment_local ? 0 : 1
  name         = "stock-responses"
  namespace_id = azurerm_servicebus_namespace.scoutify[0].id
}

resource "azurerm_key_vault" "scoutify" {
  count               = var.deployment_local ? 0 : 1
  name                = var.key_vault_name
  location            = azurerm_resource_group.scoutify[0].location
  resource_group_name = azurerm_resource_group.scoutify[0].name
  tenant_id           = data.azurerm_client_config.current[0].tenant_id
  sku_name            = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = {
    app         = "scoutify"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_key_vault_access_policy" "current_user" {
  count        = var.deployment_local ? 0 : 1
  key_vault_id = azurerm_key_vault.scoutify[0].id
  tenant_id    = data.azurerm_client_config.current[0].tenant_id
  object_id    = data.azurerm_client_config.current[0].object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_secret" "openai" {
  count        = var.deployment_local ? 0 : 1
  name         = "openai-api-key"
  value        = "PLACEHOLDER-OPENAI-KEY"
  key_vault_id = azurerm_key_vault.scoutify[0].id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "alphavantage" {
  count        = var.deployment_local ? 0 : 1
  name         = "alpha-vantage"
  value        = "PLACEHOLDER-ALPHA-VANTAGE-KEY"
  key_vault_id = azurerm_key_vault.scoutify[0].id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "finnhub" {
  count        = var.deployment_local ? 0 : 1
  name         = "finnhub"
  value        = "PLACEHOLDER-FINNHUB-KEY"
  key_vault_id = azurerm_key_vault.scoutify[0].id
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}

