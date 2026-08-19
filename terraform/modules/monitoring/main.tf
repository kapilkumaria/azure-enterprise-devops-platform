resource "azurerm_log_analytics_workspace" "this" {
  name = "log-${var.project_name}-${var.environment}-cac"

  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = var.tags
}


resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "dcr-${var.project_name}-${var.environment}-container-insights"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      name                  = "ciworkspace"
    }
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"

      streams = [
        "Microsoft-ContainerLogV2",
        "Microsoft-KubeEvents",
        "Microsoft-KubePodInventory"
      ]

      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }

  data_flow {
    streams = [
      "Microsoft-ContainerLogV2",
      "Microsoft-KubeEvents",
      "Microsoft-KubePodInventory"
    ]

    destinations = [
      "ciworkspace"
    ]
  }

  tags = var.tags
}

resource "azurerm_monitor_data_collection_rule_association" "aks_container_insights" {
  name = "dcra-${var.project_name}-${var.environment}-container-insights"

  target_resource_id      = var.aks_resource_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}
