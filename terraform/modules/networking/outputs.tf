output "vnet_id" {
  description = "ID of the platform virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the platform virtual network."
  value       = azurerm_virtual_network.this.name
}

output "aks_subnet_id" {
  description = "ID of the subnet used by AKS."
  value       = azurerm_subnet.aks.id
}

output "private_endpoint_subnet_id" {
  description = "ID of the subnet used by Azure private endpoints."
  value       = azurerm_subnet.private_endpoints.id
}
