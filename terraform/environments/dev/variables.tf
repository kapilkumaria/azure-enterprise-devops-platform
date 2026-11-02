variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "canadacentral"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project identifier."
  type        = string
  default     = "aedp"
}

variable "owner" {
  description = "Resource owner used for tagging."
  type        = string
  default     = "kapil"
}

variable "vnet_address_space" {
  description = "Address space for the DEV virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "aks_subnet_prefixes" {
  description = "Subnet prefixes reserved for AKS."
  type        = list(string)
  default     = ["10.20.0.0/20"]
}

variable "private_endpoint_subnet_prefixes" {
  description = "Subnet prefixes reserved for private endpoints."
  type        = list(string)
  default     = ["10.20.16.0/24"]
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
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
