variable "resource_group_name" {
  description = "Resource group where Key Vault will be created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
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
  description = "Globally unique suffix used in the Key Vault name."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}


variable "key_vault_allowed_ipv4_cidrs" {
  description = "Approved public IPv4 CIDRs permitted to access Key Vault. Configure before deployment."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.key_vault_allowed_ipv4_cidrs :
      can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")
    ])
    error_message = "Provide valid IPv4 CIDR ranges only."
  }
}
