output "resource_group_name" {
  description = "Resource group containing Terraform remote state resources."
  value       = azurerm_resource_group.terraform_state.name
}

output "storage_account_name" {
  description = "Storage account used for Terraform remote state."
  value       = azurerm_storage_account.terraform_state.name
}

output "container_name" {
  description = "Blob container used for Terraform remote state."
  value       = azurerm_storage_container.terraform_state.name
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state storage account."
  value       = azurerm_storage_account.terraform_state.id
}
