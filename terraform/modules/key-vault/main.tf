resource "azurerm_key_vault" "this" {
  name = "kv-${var.project_name}-${var.environment}-${var.unique_suffix}"

  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id

  sku_name = "standard"

  rbac_authorization_enabled = true


  # Explicit network boundary for Key Vault.
  # Do not apply until AKS and deployment-agent connectivity
  # has been confirmed and authorized.
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules       = var.key_vault_allowed_ipv4_cidrs
  }

  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  public_network_access_enabled = true

  tags = var.tags

  # Deployment safety: require explicit network authorization.
  # Keep this guard until approved private connectivity is
  # implemented and validated.
  lifecycle {
    precondition {
      condition     = length(var.key_vault_allowed_ipv4_cidrs) > 0
      error_message = "Configure an approved Key Vault IPv4 allowlist before deployment. Do not apply a default-deny firewall with no authorized access path."
    }
  }

}
