variable "resource_group_name" {
  description = "Resource group where AKS will be deployed."
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

variable "aks_subnet_id" {
  description = "Subnet ID used by AKS nodes."
  type        = string
}

variable "control_plane_identity_id" {
  description = "User-assigned identity resource ID used by the AKS control plane."
  type        = string
}

variable "node_vm_size" {
  description = "VM size used for the AKS system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_count" {
  description = "Initial node count for the system node pool."
  type        = number
  default     = 1
}

variable "system_node_min_count" {
  description = "Minimum system node pool size."
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum system node pool size."
  type        = number
  default     = 3
}

variable "pod_cidr" {
  description = "CIDR used for Azure CNI Overlay pod addressing."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR used for Kubernetes services."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address used by Kubernetes DNS."
  type        = string
  default     = "10.0.0.10"
}

variable "tags" {
  description = "Common tags applied to AKS resources."
  type        = map(string)
  default     = {}
}

variable "system_node_auto_scaling_enabled" {
  description = "Whether autoscaling is enabled for the AKS system node pool."
  type        = bool
  default     = false
}

variable "user_node_vm_size" {
  description = "VM size used for the AKS user node pool."
  type        = string
  default     = "Standard_D4as_v4"
}

variable "user_node_count" {
  description = "Initial number of nodes in the AKS user node pool."
  type        = number
  default     = 1
}

variable "user_node_min_count" {
  description = "Minimum number of nodes in the AKS user node pool."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum number of nodes in the AKS user node pool."
  type        = number
  default     = 2
}

variable "user_node_auto_scaling_enabled" {
  description = "Whether cluster autoscaling is enabled for the AKS user node pool."
  type        = bool
  default     = true
}
