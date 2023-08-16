variable "location" {
  type        = string
  default     = "West Europe"
  description = <<EOF
Azure region where the resource group will be created.
EOF
}

variable "databases" {
  type = map(object({
    db_name                 = string
    sku                     = string
    enable_private_endpoint = bool
  }))
  default = {
    mydemo1 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
    mydemo2 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
    mydemo3 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
  }
  description = <<EOF
Map of databases to create.

Each database is represented by a map with the following keys:
- db_name: The name of the database.
- sku: SKU string of the database, defaults to S0.
- enable_private_endpoint: Whether to enable private endpoint for the database.

Here is full example:

    mydemo1 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
    mydemo2 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
    mydemo3 = {
      db_name                 = "mydemo"
      sku                     = "S0"
      enable_private_endpoint = true
    }
    
EOF
}
