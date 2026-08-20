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


resource "azurerm_monitor_diagnostic_setting" "aks_control_plane" {
  name                       = "diag-${var.project_name}-${var.environment}-aks"
  target_resource_id         = var.aks_resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }
}


resource "azurerm_monitor_action_group" "platform_ops" {
  name                = "ag-${var.project_name}-${var.environment}-ops"
  resource_group_name = var.resource_group_name
  short_name          = "aedpops"

  email_receiver {
    name                    = "primary-email"
    email_address           = "kapil.kumaria@gmail.com"
    use_common_alert_schema = true
  }

  tags = var.tags
}


resource "azurerm_monitor_scheduled_query_rules_alert_v2" "unhealthy_application_pods" {
  name                = "alert-${var.project_name}-${var.environment}-unhealthy-pods"
  resource_group_name = var.resource_group_name
  location            = var.location

  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"

  scopes = [
    azurerm_log_analytics_workspace.this.id
  ]

  severity = 2
  enabled  = true

  criteria {
    query = <<-KQL
      KubePodInventory
      | where Namespace in (
          "applications",
          "applications-staging",
          "applications-prod"
        )
      | where PodStatus != "Running"
      | summarize ProblemPods=count()
    KQL

    time_aggregation_method = "Maximum"
    threshold               = 0
    operator                = "GreaterThan"

    metric_measure_column = "ProblemPods"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [
      azurerm_monitor_action_group.platform_ops.id
    ]
  }

  description = "Alerts when any application pod is not in Running state."

  tags = var.tags
}
