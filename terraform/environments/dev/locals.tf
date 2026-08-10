locals {
  location_short = "cac"

  common_tags = {
    Project     = "azure-enterprise-devops-platform"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}
