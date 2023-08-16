resource "random_string" "sql" {
  lower   = true
  upper   = false
  numeric = false
  special = false
  length  = 8
}

resource "random_password" "sql" {
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  length      = 16
}

resource "azurerm_mssql_server" "main" {
  name                         = "${var.sql_server_prefix}-${random_string.sql.result}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "tomas"
  administrator_login_password = random_password.sql.result
}

resource "azurerm_key_vault_secret" "main" {
  name         = azurerm_mssql_server.main.name
  value        = random_password.sql.result
  key_vault_id = var.key_vault_id
}

resource "azurerm_mssql_database" "main" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 1
  read_scale     = false
  sku_name       = var.sql_database_sku
  zone_redundant = false
}

resource "azurerm_private_endpoint" "main" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "sql-endpoint"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = azurerm_mssql_server.main.name
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = azurerm_mssql_server.main.name
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
