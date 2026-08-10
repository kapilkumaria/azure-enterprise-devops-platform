locals {
  location_short = "cac"

  resource_group_name = "rg-${var.project_name}-tfstate-${local.location_short}"

  common_tags = {
    Project     = "azure-enterprise-devops-platform"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Purpose     = "Terraform remote state"
  }
}
