variable "resource_group_name" {
  description = "Resource group containing networking resources."
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

variable "location_short" {
  description = "Short Azure region identifier."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space assigned to the platform virtual network."
  type        = list(string)
}

variable "aks_subnet_prefixes" {
  description = "CIDR prefixes assigned to the AKS subnet."
  type        = list(string)
}

variable "private_endpoint_subnet_prefixes" {
  description = "CIDR prefixes assigned to the private endpoint subnet."
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to networking resources."
  type        = map(string)
  default     = {}
}
