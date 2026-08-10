resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.project_name}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name

  address_space = var.vnet_address_space

  tags = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = var.aks_subnet_prefixes
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = var.private_endpoint_subnet_prefixes

  private_endpoint_network_policies = "Disabled"
}
