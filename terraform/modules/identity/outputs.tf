output "aks_control_plane_identity_id" {
  description = "Resource ID of the AKS control-plane managed identity."
  value       = azurerm_user_assigned_identity.aks_control_plane.id
}

output "aks_control_plane_client_id" {
  description = "Client ID of the AKS control-plane managed identity."
  value       = azurerm_user_assigned_identity.aks_control_plane.client_id
}

output "aks_control_plane_principal_id" {
  description = "Principal ID of the AKS control-plane managed identity."
  value       = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

output "workload_identity_id" {
  description = "Resource ID of the application workload managed identity."
  value       = azurerm_user_assigned_identity.workload.id
}

output "workload_client_id" {
  description = "Client ID of the application workload managed identity."
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "workload_principal_id" {
  description = "Principal ID of the application workload managed identity."
  value       = azurerm_user_assigned_identity.workload.principal_id
}
