resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "terraform_state" {
  name     = local.resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_storage_account" "terraform_state" {
  name = "staedptf${random_string.storage_suffix.result}"

  resource_group_name = azurerm_resource_group.terraform_state.name
  location            = azurerm_resource_group.terraform_state.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version = "TLS1_2"

  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"

    ip_rules = [
      var.admin_public_ip
    ]

    bypass = [
      "AzureServices"
    ]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "terraform_state" {
  name = "tfstate"

  storage_account_id = azurerm_storage_account.terraform_state.id

  container_access_type = "private"
}
