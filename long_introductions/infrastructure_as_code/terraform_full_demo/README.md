<!-- BEGIN_TF_DOCS -->
# This is my demo project
Here comes some text
- bullet 1
- bullet 2

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~>3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~>3 |
| <a name="provider_random"></a> [random](#provider\_random) | ~>3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sql"></a> [sql](#module\_sql) | github.com/tkubica12/keep-long-story-long//long_introductions/infrastructure_as_code/terraform_full_demo/modules/azuresql | azuresql-v1.0.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_private_dns_zone.sql](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.sql](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subnet.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [random_string.key_vault](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_databases"></a> [databases](#input\_databases) | Map of databases to create.<br><br>Each database is represented by a map with the following keys:<br>- db\_name: The name of the database.<br>- sku: SKU string of the database, defaults to S0.<br>- enable\_private\_endpoint: Whether to enable private endpoint for the database.<br><br>Here is full example:<pre>mydemo1 = {<br>      db_name                 = "mydemo"<br>      sku                     = "S0"<br>      enable_private_endpoint = true<br>    }<br>    mydemo2 = {<br>      db_name                 = "mydemo"<br>      sku                     = "S0"<br>      enable_private_endpoint = true<br>    }<br>    mydemo3 = {<br>      db_name                 = "mydemo"<br>      sku                     = "S0"<br>      enable_private_endpoint = true<br>    }</pre> | <pre>map(object({<br>    db_name                 = string<br>    sku                     = string<br>    enable_private_endpoint = bool<br>  }))</pre> | <pre>{<br>  "mydemo1": {<br>    "db_name": "mydemo",<br>    "enable_private_endpoint": true,<br>    "sku": "S0"<br>  },<br>  "mydemo2": {<br>    "db_name": "mydemo",<br>    "enable_private_endpoint": true,<br>    "sku": "S0"<br>  },<br>  "mydemo3": {<br>    "db_name": "mydemo",<br>    "enable_private_endpoint": true,<br>    "sku": "S0"<br>  }<br>}</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the resource group will be created. | `string` | `"West Europe"` | no |

## Outputs

No outputs.

# Author
Tomas Kubica
<!-- END_TF_DOCS -->