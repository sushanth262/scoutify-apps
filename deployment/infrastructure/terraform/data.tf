data "azurerm_client_config" "current" {
  count = var.deployment_local ? 0 : 1
}
