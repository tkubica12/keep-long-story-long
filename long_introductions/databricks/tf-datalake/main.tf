locals {
  resource_group = "databricks"
  location       = "northeurope"
}

resource "random_string" "main" {
  length  = 12
  special = false
  numeric = false
  upper   = false
  lower   = true
}

// Create Key Vault
resource "azurerm_key_vault" "main" {
  name                       = random_string.main.result
  resource_group_name        = local.resource_group
  location                   = local.location
  enable_rbac_authorization  = true
  tenant_id                  = data.azurerm_client_config.main.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"
}

// Assign current user as admin
data "azurerm_client_config" "main" {
}

resource "azurerm_role_assignment" "currentuser-kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.main.object_id
}

// Data Lake and data generation
module "data_lake" {
  source              = "github.com/tkubica12/dataplayground//terraform/modules/data_lake"
  name_prefix         = random_string.main.result
  resource_group_name = local.resource_group
  location            = local.location
  keyvault_id         = azurerm_key_vault.main.id
  users_count         = 100000
  vip_users_count     = 50000
  products_count      = 10000
  orders_count        = 100000

  depends_on = [
    azurerm_role_assignment.currentuser-kv
  ]
}

// Authorization to Event Hub for Databrics
resource "azurerm_eventhub_authorization_rule" "pageviewsReceiver" {
  name                = "pageviewsReceiver"
  namespace_name      = module.data_lake.eventhub_namespace_name
  resource_group_name = local.resource_group
  eventhub_name       = module.data_lake.eventhub_name_pageviews
  listen              = true
  send                = false
  manage              = false
}

resource "azurerm_eventhub_authorization_rule" "starsReceiver" {
  name                = "starsReceiver"
  namespace_name      = module.data_lake.eventhub_namespace_name
  resource_group_name = local.resource_group
  eventhub_name       = module.data_lake.eventhub_name_stars
  listen              = true
  send                = false
  manage              = false
}
