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
