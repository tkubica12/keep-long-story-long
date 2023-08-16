resource "azurerm_resource_group" "main" {
  name     = "tf-demo-rg"
  location = "West Europe"
}

module "sql" {
  source                  = "github.com/tkubica12/keep-long-story-long//long_introductions/infrastructure_as_code/terraform_full_demo/modules/azuresql?ref=azuresql-v1.0.0"
  for_each                = fileset("${path.module}/databases", "*.yaml")
  sql_server_prefix       = element(split(".", each.key), 0)
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  key_vault_id            = azurerm_key_vault.main.id
  sql_database_name       = yamldecode(file("${path.module}/databases/${each.key}")).db_name
  sql_database_sku        = yamldecode(file("${path.module}/databases/${each.key}")).sku
  enable_private_endpoint = yamldecode(file("${path.module}/databases/${each.key}")).enable_private_endpoint
  subnet_id               = azurerm_subnet.main.id
  private_dns_zone_id     = azurerm_private_dns_zone.sql.id
}
