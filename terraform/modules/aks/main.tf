resource "azurerm_kubernetes_cluster" "this" {
  name = "aks-${var.project_name}-${var.environment}-${var.location_short}"

  location            = var.location
  resource_group_name = var.resource_group_name

  dns_prefix = "aks-${var.project_name}-${var.environment}"

  sku_tier = "Free"

  node_provisioning_profile {
    mode = "Manual"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  role_based_access_control_enabled = true

  default_node_pool {
    name = "system"

    vm_size = var.node_vm_size

    vnet_subnet_id = var.aks_subnet_id

    auto_scaling_enabled = var.system_node_auto_scaling_enabled
    node_count           = var.system_node_count

    type = "VirtualMachineScaleSets"

    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }

    tags = var.tags
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      var.control_plane_identity_id
    ]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"

    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip

    load_balancer_sku = "standard"

    outbound_type = "loadBalancer"
  }

  tags = var.tags
}
