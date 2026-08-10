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
