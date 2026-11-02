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

  tenant_id = var.tenant_id

  aks_subnet_id = module.networking.aks_subnet_id

  control_plane_identity_id  = module.identity.aks_control_plane_identity_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  node_vm_size = "Standard_D4s_v6"

  system_node_count                = 2
  system_node_auto_scaling_enabled = false

  user_node_vm_size = "Standard_D2s_v6"

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

resource "azurerm_federated_identity_credential" "workload" {
  name = "fic-${var.project_name}-${var.environment}-workload"

  user_assigned_identity_id = module.identity.workload_identity_id

  issuer = module.aks.oidc_issuer_url

  audience = [
    "api://AzureADTokenExchange"
  ]

  subject = "system:serviceaccount:applications:workload-identity-sa"
}


resource "azurerm_federated_identity_credential" "workload_staging" {
  name = "fic-${var.project_name}-${var.environment}-workload-staging"

  user_assigned_identity_id = module.identity.workload_identity_id

  issuer = module.aks.oidc_issuer_url

  audience = [
    "api://AzureADTokenExchange"
  ]

  subject = "system:serviceaccount:applications-staging:workload-identity-sa"
}


resource "azurerm_federated_identity_credential" "workload_prod" {
  name = "fic-${var.project_name}-${var.environment}-workload-prod"

  user_assigned_identity_id = module.identity.workload_identity_id

  issuer = module.aks.oidc_issuer_url

  audience = [
    "api://AzureADTokenExchange"
  ]

  subject = "system:serviceaccount:applications-prod:workload-identity-sa"
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

resource "random_string" "key_vault_suffix" {
  length  = 6
  upper   = false
  special = false
}

module "key_vault" {
  key_vault_allowed_ipv4_cidrs = var.key_vault_allowed_ipv4_cidrs

  source = "../../modules/key-vault"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tenant_id           = var.tenant_id

  project_name  = var.project_name
  environment   = var.environment
  unique_suffix = random_string.key_vault_suffix.result

  tags = local.common_tags
}

resource "azurerm_role_assignment" "workload_key_vault_secrets_user" {
  scope = module.key_vault.id

  role_definition_name = "Key Vault Secrets User"

  principal_id = module.identity.workload_principal_id
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  project_name = var.project_name
  environment  = var.environment

  aks_resource_id = module.aks.id

  tags = local.common_tags
}
