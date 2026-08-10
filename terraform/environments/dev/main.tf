resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.project_name}-${var.environment}-${local.location_short}"
  location = var.location

  tags = merge(
    local.common_tags,
    {
      Purpose = "Azure enterprise DevOps platform"
    }
  )
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  project_name   = var.project_name
  environment    = var.environment
  location_short = local.location_short

  vnet_address_space               = var.vnet_address_space
  aks_subnet_prefixes              = var.aks_subnet_prefixes
  private_endpoint_subnet_prefixes = var.private_endpoint_subnet_prefixes

  tags = local.common_tags
}

resource "random_string" "acr_suffix" {
  length  = 6
  upper   = false
  special = false
}

module "acr" {
  source = "../../modules/acr"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  project_name  = var.project_name
  environment   = var.environment
  unique_suffix = random_string.acr_suffix.result

  sku  = "Standard"
  tags = local.common_tags
}

module "identity" {
  source = "../../modules/identity"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  project_name   = var.project_name
  environment    = var.environment
  location_short = local.location_short

  tags = local.common_tags
}
