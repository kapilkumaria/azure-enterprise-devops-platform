variable "resource_group_name" {
  description = "Resource group where ACR will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "project_name" {
  description = "Short project identifier."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "unique_suffix" {
  description = "Globally unique suffix used in the ACR name."
  type        = string
}

variable "sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
  default     = {}
}
