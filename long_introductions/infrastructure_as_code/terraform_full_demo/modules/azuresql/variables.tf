variable "sql_server_prefix" {
  type        = string
  description = <<EOF
The prefix of the SQL Server object in Azure
EOF
}

variable "sql_database_name" {
  type        = string
  description = <<EOF
The name of SQL database.
EOF
}

variable "sql_database_sku" {
  type        = string
  default     = "S0"
  description = <<EOF
SKU string of SQL database, defaults to S0.
EOF
}

variable "location" {
  type        = string
  description = <<EOF
The location of the SQL Server object in Azure.
EOF
}

variable "resource_group_name" {
  type        = string
  description = <<EOF
The name of the resource group in Azure into which the SQL Server object will be deployed.
EOF
}

variable "key_vault_id" {
  type        = string
  description = <<EOF
The ID of the Key Vault object in Azure into which generated SQL server password will be stored.
EOF
}

variable "enable_private_endpoint" {
  type        = bool
  default     = false
  description = <<EOF
Whether to enable private endpoint for the SQL Server.
EOF
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = <<EOF
ID of the subnet to which the private endpoint will be attached.
EOF
}

variable "private_dns_zone_id" {
  type        = string
  default     = ""
  description = <<EOF
ID of the private DNS zone to which the private endpoint will be attached.
EOF
}
