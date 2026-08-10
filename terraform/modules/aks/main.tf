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

  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }

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

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name = "user"

  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id

  vm_size = var.user_node_vm_size

  vnet_subnet_id = var.aks_subnet_id

  mode = "User"

  auto_scaling_enabled = var.user_node_auto_scaling_enabled

  min_count  = var.user_node_min_count
  max_count  = var.user_node_max_count
  node_count = var.user_node_count

  node_labels = {
    "workload" = "applications"
  }

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}
