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

module "aks" {
  source = "../../modules/aks"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  project_name   = var.project_name
  environment    = var.environment
  location_short = local.location_short

  aks_subnet_id = module.networking.aks_subnet_id

  control_plane_identity_id = module.identity.aks_control_plane_identity_id

  node_vm_size = "Standard_D4s_v6"

  system_node_count                = 2
  system_node_auto_scaling_enabled = false

  user_node_vm_size = "Standard_D4as_v4"

  user_node_count                = 1
  user_node_min_count            = 1
  user_node_max_count            = 2
  user_node_auto_scaling_enabled = true

  pod_cidr       = "10.244.0.0/16"
  service_cidr   = "10.0.0.0/16"
  dns_service_ip = "10.0.0.10"

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.aks_network_contributor
  ]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope = module.acr.id

  role_definition_name = "AcrPull"

  principal_id = module.aks.kubelet_identity_object_id
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope = module.networking.aks_subnet_id

  role_definition_name = "Network Contributor"

  principal_id = module.identity.aks_control_plane_principal_id
}
