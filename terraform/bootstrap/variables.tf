variable "subscription_id" {
  description = "Azure subscription ID where bootstrap resources will be created."
  type        = string
}

variable "location" {
  description = "Primary Azure region for bootstrap resources."
  type        = string
  default     = "canadacentral"
}

variable "project_name" {
  description = "Short project identifier used for resource naming."
  type        = string
  default     = "aedp"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "shared"
}

variable "owner" {
  description = "Owner tag applied to Azure resources."
  type        = string
  default     = "kapil"
}

variable "admin_public_ip" {
  description = "Public IPv4 address allowed to access the Terraform backend storage account."
  type        = string
}
