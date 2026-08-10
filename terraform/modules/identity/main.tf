resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name = "id-aks-control-${var.project_name}-${var.environment}-${var.location_short}"

  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "workload" {
  name = "id-workload-${var.project_name}-${var.environment}-${var.location_short}"

  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}
