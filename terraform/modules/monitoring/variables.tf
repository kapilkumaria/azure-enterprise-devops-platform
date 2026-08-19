variable "resource_group_name" {
  description = "Resource group where monitoring resources are created."
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

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "aks_resource_id" {
  description = "AKS cluster resource ID for Container Insights DCR association."
  type        = string
}
