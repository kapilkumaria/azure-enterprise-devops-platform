terraform {
  backend "azurerm" {
    use_cli          = true
    use_azuread_auth = true

    storage_account_name = "staedptf3zhr91"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
