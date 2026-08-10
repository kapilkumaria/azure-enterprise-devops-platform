variable "resource_group_name" {
  description = "Resource group containing managed identities."
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

variable "tags" {
  description = "Common tags applied to managed identities."
  type        = map(string)
  default     = {}
}
