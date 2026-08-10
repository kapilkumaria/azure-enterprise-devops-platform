output "resource_group_name" {
  description = "DEV platform resource group."
  value       = azurerm_resource_group.platform.name
}

output "vnet_name" {
  description = "DEV virtual network name."
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "DEV virtual network ID."
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "AKS subnet ID."
  value       = module.networking.aks_subnet_id
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID."
  value       = module.networking.private_endpoint_subnet_id
}

output "acr_id" {
  description = "Azure Container Registry resource ID."
  value       = module.acr.id
}

output "acr_name" {
  description = "Azure Container Registry name."
  value       = module.acr.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server."
  value       = module.acr.login_server
}

output "aks_control_plane_identity_id" {
  description = "AKS control-plane managed identity resource ID."
  value       = module.identity.aks_control_plane_identity_id
}

output "aks_control_plane_client_id" {
  description = "AKS control-plane managed identity client ID."
  value       = module.identity.aks_control_plane_client_id
}

output "workload_identity_id" {
  description = "Application workload managed identity resource ID."
  value       = module.identity.workload_identity_id
}

output "workload_client_id" {
  description = "Application workload managed identity client ID."
  value       = module.identity.workload_client_id
}
