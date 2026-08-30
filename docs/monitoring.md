# Observability and Monitoring Architecture

## Overview

The Azure Enterprise DevOps Platform uses Azure-native observability services to provide visibility into the health, performance, and operational state of Azure Kubernetes Service and the applications running on it.

The monitoring architecture combines:

* Azure Monitor
* Log Analytics
* Container Insights
* Data Collection Rules
* AKS diagnostic settings
* scheduled query alert rules
* Azure Monitor Action Groups
* Kubernetes resource metrics
* Horizontal Pod Autoscaler telemetry
* AKS node and workload health information

The objective is not simply to collect logs.

The platform is designed to support three operational functions:

```text
Observe
   |
   v
Investigate
   |
   v
Alert
```

This allows engineers to understand current platform behavior, investigate failures, and receive proactive notification when defined unhealthy conditions occur.

---

# Observability Design Principles

The monitoring implementation follows several principles:

* centralized telemetry;
* infrastructure-defined monitoring;
* proactive alerting;
* workload and platform visibility;
* actionable signals;
* reproducible configuration;
* separation of collection and alerting;
* operational troubleshooting through queryable data.

Monitoring resources are provisioned through Terraform so observability is part of the platform rather than a manual post-deployment activity.

---

# Monitoring Architecture

The platform combines AKS telemetry collection, centralized log storage, Kubernetes operational metrics, and Azure Monitor alerting.

The implemented logical telemetry flow is:

```text
AKS Cluster
    |
    +--> Kubernetes workloads
    |
    +--> Node / container telemetry
    |
    +--> AKS control-plane diagnostics
    |
    v
Data Collection Rule
    +
AKS Diagnostic Settings
    |
    v
Log Analytics Workspace
    |
    +--> KQL operational investigation
    |
    +--> Container Insights
    |
    +--> Scheduled Query Evaluation
    |
    v
Azure Monitor Alert
    |
    v
Action Group
```

Kubernetes runtime metrics provide an additional operational path:

```text
AKS Metrics Pipeline
        |
        +--> kubectl top
        |
        +--> Horizontal Pod Autoscaler
        |
        v
Runtime Resource Visibility
```

The architecture therefore supports both centralized Azure-native telemetry and direct Kubernetes operational inspection.

This creates an end-to-end path from telemetry collection through investigation and alerting while keeping the monitoring configuration reproducible through Infrastructure as Code.

---

# Terraform Monitoring Module

Monitoring infrastructure is managed through:

```text
terraform/modules/monitoring/
├── main.tf
├── outputs.tf
└── variables.tf
```

The module provisions the monitoring components required by the AKS platform.

Resources include:

* Log Analytics Workspace;
* Data Collection Rule;
* Data Collection Rule association;
* AKS diagnostic settings;
* Azure Monitor scheduled query alert;
* Azure Monitor Action Group.

This ensures that rebuilding the platform also rebuilds its monitoring configuration.

---

# Log Analytics Workspace

The Log Analytics Workspace acts as the centralized log and operational telemetry store for the Azure environment.

It provides a queryable location for supported AKS and Azure Monitor data collected through the platform monitoring configuration.

The logical architecture is:

```text
AKS
 |
 +--> Container / workload telemetry
 |
 +--> Kubernetes inventory information
 |
 +--> AKS diagnostic logs
 |
 v
Log Analytics Workspace
 |
 +--> KQL queries
 |
 +--> Historical investigation
 |
 +--> Scheduled query evaluation
```

The workspace provides centralized operational investigation rather than requiring engineers to depend only on transient pod output or individual node-level logs.

Kubernetes resource metrics used by commands such as `kubectl top` and by the Horizontal Pod Autoscaler represent a related but separate runtime metrics path.

This distinction is important because logs, Kubernetes resource metrics, and application metrics serve different observability purposes.

---

# Why Centralized Logging Matters

Without centralized logging, investigation may require engineers to:

* connect to individual machines;
* inspect local logs;
* correlate timestamps manually;
* search multiple systems independently.

With centralized telemetry:

```text
Multiple Workloads
       |
       v
Central Workspace
       |
       v
Single Query Interface
```

This significantly improves operational investigation.

---

# Kusto Query Language

Log Analytics data can be investigated using Kusto Query Language.

KQL allows engineers to filter, aggregate, correlate, and analyze Azure and Kubernetes telemetry.

Typical operational questions include:

* Which pods are failing?
* Which namespaces have unhealthy workloads?
* When did failures begin?
* Which container generated an error?
* Are failures concentrated on a specific node?
* Is a condition recurring?
* Did application behavior change after deployment?

![Log Analytics query returning AKS-related telemetry](images/monitoring/log-analytics-query.png)

*Demonstrates query-driven operational troubleshooting.*

---

# Container Insights

Azure Monitor Container Insights provides Kubernetes-specific observability for AKS.

The platform integrates AKS monitoring with the Log Analytics Workspace through the Terraform-managed monitoring configuration.

Container Insights provides visibility into Kubernetes infrastructure and workload information such as:

* cluster state;
* nodes;
* controllers;
* pods;
* containers;
* resource utilization;
* workload inventory.

The relationship is:

```text
AKS Cluster
      |
      v
Azure Monitor Container Insights
      |
      +--> Cluster visibility
      +--> Node visibility
      +--> Pod / container visibility
      +--> Workload inventory
      |
      v
Operational Investigation
```

This gives platform engineers an Azure-native operational view of the Kubernetes environment while command-line tools remain available for immediate runtime investigation.

![AKS Container Insights showing live cluster/workload telemetry](images/monitoring/container-insights.png)

*Demonstrates Azure-native Kubernetes observability.*

---

# Data Collection Rule

Azure Monitor Data Collection Rules define supported telemetry collection and routing behavior.

The platform provisions the AKS monitoring DCR through Terraform and associates it with the cluster.

Conceptually:

```text
AKS Cluster
     |
     v
Data Collection Rule
     |
     +--> Collection configuration
     |
     +--> Data routing
     |
     v
Log Analytics Workspace
```

The DCR makes telemetry collection part of the declared infrastructure configuration rather than a portal-only setting.

This provides several operational advantages:

* reproducible monitoring configuration;
* version-controlled infrastructure changes;
* consistent environment reconstruction;
* reduced configuration drift;
* auditable monitoring changes.

The DCR itself defines collection behavior, while the DCR association connects that configuration to the AKS resource.

---

# Data Collection Rule Association

Creating a Data Collection Rule alone is insufficient.

The rule must be associated with the target resource.

The platform therefore provisions the DCR association linking the monitoring rule to AKS.

This distinction is important:

```text
DCR Exists
    !=
AKS Using DCR
```

The association activates the relationship between the cluster and telemetry configuration.

---

# AKS Diagnostic Settings

AKS diagnostic settings provide visibility into Azure-managed AKS platform and control-plane activity.

The Terraform monitoring configuration routes the selected AKS diagnostic categories to the Log Analytics Workspace.

Conceptually:

```text
AKS Control Plane / Platform
            |
            v
Azure Monitor Diagnostic Settings
            |
            v
Log Analytics Workspace
            |
            v
KQL Investigation
```

This telemetry complements container and workload observability.

The distinction is important:

```text
Container / Workload Telemetry
        |
        +--> Application and Kubernetes runtime behavior

AKS Diagnostic Logs
        |
        +--> Azure-managed AKS platform activity
```

Together, these signals provide visibility across both Kubernetes workloads and the managed AKS platform.

---

# Workload Monitoring

Monitoring must include application workloads, not just the Kubernetes cluster itself.

The platform therefore considers signals associated with:

* Deployment health;
* Pod status;
* container state;
* restart behavior;
* resource utilization;
* replica count;
* autoscaling behavior.

A cluster can be technically available while an application running inside it is unhealthy.

Therefore:

```text
Cluster Healthy
      !=
Application Healthy
```

Both platform and workload signals matter.

---

# Kubernetes Operational Validation

Command-line validation remains useful alongside Azure-native monitoring.

Examples include:

```bash
kubectl get pods -A
```

```bash
kubectl get deployments -A
```

```bash
kubectl get hpa -A
```

```bash
kubectl top nodes
```

```bash
kubectl top pods -A
```

These commands provide immediate runtime visibility and complement centralized monitoring.

---

# Azure Monitor Alerting

The platform provisions an Azure Monitor scheduled query alert through Terraform.

The alert evaluates telemetry stored in Log Analytics to detect defined unhealthy workload conditions.

The implemented operational path is:

```text
AKS Workload
      |
      v
Telemetry Collection
      |
      v
Log Analytics Workspace
      |
      v
Scheduled KQL Evaluation
      |
      +--> Condition Not Met
      |          |
      |          v
      |       No Alert
      |
      +--> Condition Met
                 |
                 v
          Azure Monitor Alert
                 |
                 v
            Action Group
```

This moves the platform beyond passive log collection.

Instead of requiring an engineer to continuously inspect Kubernetes state, the monitoring system can evaluate a defined condition automatically and initiate the configured alert path.

![Azure Monitor scheduled query alert configuration](images/monitoring/application-alert-rule.png)

*Demonstrates proactive workload monitoring.*

---

# Scheduled Query Alerts

A scheduled query alert periodically executes a KQL query against Log Analytics and evaluates the result against a configured condition.

Conceptually:

```text
KQL Query
    |
    v
Scheduled Evaluation
    |
    +--> Threshold / condition not met
    |              |
    |              v
    |           Healthy
    |
    +--> Threshold / condition met
                   |
                   v
                Alert
```

This creates an automated detection mechanism over centralized telemetry.

The alert definition is maintained through Terraform together with the rest of the monitoring infrastructure, making the detection configuration reproducible and reviewable.

In a production environment, scheduled query alerts would normally be supplemented with additional metric alerts, service-level indicators, application-specific signals, and escalation policies.

---

# Action Groups

An Azure Monitor Action Group defines what should happen after an alert is triggered.

The architecture is:

```text
Alert Rule
    |
    v
Action Group
    |
    +--> Notification
    +--> Automation
    +--> External Integration
```

Depending on organizational requirements, Action Groups can integrate with notification and automation mechanisms.

The project provisions the Action Group through Terraform.

![Azure Monitor Action Group](images/monitoring/action-group.png)

*Demonstrates alert notification architecture.*

---

# Monitoring as Infrastructure as Code

Observability configuration is provisioned with Terraform.

This is important because monitoring should not rely on manual portal configuration that disappears when the environment is recreated.

The lifecycle becomes:

```text
Terraform
   |
   v
AKS
   +
Log Analytics
   +
DCR
   +
Diagnostic Settings
   +
Alerts
   +
Action Group
```

The infrastructure and its monitoring controls therefore evolve together.

---

# Autoscaling Observability

The platform implements multiple scaling layers.

## Horizontal Pod Autoscaler

The Kubernetes HPA adjusts application replica count according to configured metrics.

Operationally, engineers should be able to inspect:

```bash
kubectl get hpa -A
```

The HPA provides visibility into:

* current replicas;
* desired replicas;
* metric targets;
* observed utilization.

![kubectl get hpa showing application autoscaling resources](images/aks/hpa.png)

*Demonstrates application autoscaling and operational visibility.*

---

# Cluster Autoscaler

The AKS node pools support cluster autoscaling.

The relationship between the scaling mechanisms is:

```text
Application Load
      |
      v
HPA
      |
      v
Additional Pods
      |
      v
Insufficient Capacity?
      |
      v
AKS Cluster Autoscaler
      |
      v
Additional Nodes
```

HPA and cluster autoscaling solve different resource problems.

HPA scales workloads.

Cluster Autoscaler scales infrastructure capacity.

---

# Monitoring Scaling Events

Useful scaling-related signals include:

* replica count;
* HPA target utilization;
* pending pods;
* node utilization;
* node count;
* scheduling failures;
* container resource pressure.

A production monitoring strategy should detect situations where scaling is requested but infrastructure cannot satisfy demand.

---

# Resource Requests and Limits

Autoscaling and scheduler behavior depend on accurate Kubernetes resource configuration.

Requests help Kubernetes determine placement and capacity requirements.

Limits help control maximum resource consumption.

Poor resource settings can create misleading autoscaling behavior.

For example:

```text
Incorrect CPU Requests
       |
       v
Misleading HPA Utilization
       |
       v
Unexpected Scaling
```

Monitoring therefore helps validate whether resource policies are operating as intended.

---

# Application Health Versus Infrastructure Health

A mature monitoring system distinguishes several failure domains.

```text
Azure Platform
      |
      v
AKS Cluster
      |
      v
Kubernetes Node
      |
      v
Pod
      |
      v
Container
      |
      v
Application
```

A failure may occur at any one of these layers.

For example:

* Azure resource unavailable;
* node unhealthy;
* pod unschedulable;
* container crash loop;
* application returns errors.

Observability should help engineers determine which layer is responsible.

---

# Deployment Monitoring

CI/CD deployment validation should be connected conceptually to operational monitoring.

A deployment flow should not end with:

```text
kubectl apply
```

Instead:

```text
Deployment
    |
    v
Rollout Validation
    |
    v
Application Health
    |
    v
Monitoring
```

A release is not operationally successful merely because Kubernetes accepted the manifest.

---

# Alert Quality

Alerts should be actionable.

Poor alert design creates excessive noise and eventually causes operators to ignore notifications.

Useful alerting should consider:

* severity;
* duration;
* business impact;
* recurrence;
* threshold;
* routing.

The goal is:

```text
Meaningful Condition
       |
       v
Actionable Alert
```

rather than:

```text
Every Minor Event
       |
       v
Alert Storm
```

---

# Operational Troubleshooting Workflow

A typical investigation may follow:

```text
Alert Received
     |
     v
Determine Scope
     |
     v
Inspect AKS / Workload State
     |
     v
Query Log Analytics
     |
     v
Identify Failure Domain
     |
     v
Remediate
     |
     v
Validate Recovery
```

This workflow combines alerting, Kubernetes commands, Azure monitoring, and centralized logs.

---

# Example Failure Scenario

Consider an application whose pods begin failing.

The operational path could be:

```text
Pod Failures
    |
    v
Telemetry Collected
    |
    v
Log Analytics
    |
    v
Scheduled Query Alert
    |
    v
Action Group
    |
    v
Engineer Investigation
```

The engineer can then correlate:

```bash
kubectl get pods -n <namespace>
```

with Log Analytics telemetry to determine the failure cause.

---

# Controlled Monitoring Validation

# Monitoring Validation Strategy

Monitoring resources should be validated at multiple levels rather than assuming that successful Terraform provisioning proves the complete operational path.

The platform can be validated through:

```text
Infrastructure Validation
        |
        +--> Monitoring resources exist
        |
        v
Telemetry Validation
        |
        +--> AKS data reaches Log Analytics
        |
        v
Query Validation
        |
        +--> KQL returns expected telemetry
        |
        v
Alert Validation
        |
        +--> Alert rule is configured and enabled
        |
        v
Notification Validation
        |
        +--> Action Group path is verified
```

For a production implementation, the strongest validation would introduce a controlled failure into a non-production workload and verify the complete detection path:

```text
Controlled Failure
       |
       v
Unhealthy Workload
       |
       v
Telemetry Captured
       |
       v
Alert Condition Met
       |
       v
Azure Monitor Alert
       |
       v
Action Group
       |
       v
Operational Response
```

The workload should then be restored and recovery confirmed.

This type of controlled failure testing validates the observability system as an operational capability rather than merely confirming that monitoring resources exist.

---

# Evidence to Capture

The final portfolio evidence should demonstrate:

1. AKS Container Insights;
2. Log Analytics query returning AKS information;
3. Azure Monitor scheduled query alert;
4. Azure Monitor Action Group;
5. Kubernetes HPA state;
6. healthy cluster/workload state.

The strongest screenshots are those that demonstrate an operational capability rather than merely showing that a resource exists.

---

# Monitoring Screenshot Safety

Monitoring screenshots should be reviewed before committing.

Avoid exposing:

* subscription identifiers where unnecessary;
* email addresses;
* notification endpoints;
* authentication information;
* sensitive application logs;
* secret values;
* customer or personal data.

Crop or redact screenshots when required.

---

# Current Observability Scope

The current portfolio implementation focuses on Azure-native infrastructure and Kubernetes operational observability.

Implemented capabilities include:

* Terraform-managed Log Analytics Workspace;
* AKS telemetry collection configuration;
* Data Collection Rule;
* Data Collection Rule association;
* AKS diagnostic settings;
* Azure Monitor Container Insights;
* KQL-based operational investigation;
* scheduled query alerting;
* Azure Monitor Action Group;
* Kubernetes resource metrics;
* Horizontal Pod Autoscaler visibility;
* AKS Cluster Autoscaler visibility;
* Kubernetes command-line operational validation.

The implementation therefore provides a monitoring foundation across infrastructure, Kubernetes workloads, centralized telemetry, and alerting.

It does not claim to implement a complete enterprise SRE observability stack.

---

# Production Observability Enhancements

A production implementation could extend the current platform with:

* Azure Monitor managed service for Prometheus;
* Azure Managed Grafana;
* OpenTelemetry;
* distributed tracing;
* Application Insights;
* custom application metrics;
* RED metrics for request-driven services;
* USE metrics for infrastructure resources;
* synthetic availability monitoring;
* external health probes;
* centralized operational dashboards;
* SLI and SLO definitions;
* error-budget monitoring;
* alert escalation policies;
* incident-management integration;
* Microsoft Sentinel integration;
* longer-term telemetry retention;
* monitoring cost controls;
* automated remediation workflows.

The appropriate observability architecture depends on application architecture, reliability objectives, operational maturity, regulatory requirements, telemetry volume, and cost.

---

# SLI and SLO Evolution

The next maturity step beyond infrastructure-centric monitoring is service-level reliability measurement.

For example:

```text
Infrastructure Signal
CPU / Memory / Pod Health
          |
          v
Application Signal
Latency / Errors / Request Rate
          |
          v
Service-Level Indicator
Successful Request Percentage
          |
          v
Service-Level Objective
99.9% Successful Requests
          |
          v
Error Budget
          |
          v
Reliability Decision
```

This changes the operational question from:

```text
"Is the infrastructure running?"
```

to:

```text
"Is the service meeting its reliability objective for users?"
```

The current project establishes the telemetry and alerting foundation on which more advanced SLI, SLO, and error-budget practices could be built.

---

# DORA and Delivery Observability

Infrastructure and application observability can also be correlated with software-delivery telemetry.

Useful delivery metrics include:

* deployment frequency;
* lead time for changes;
* change failure rate;
* failed deployment recovery time.

Conceptually:

```text
Azure DevOps
     |
     +--> Build / Deployment Data
     |
     v
Delivery Performance

Azure Monitor / AKS
     |
     +--> Runtime / Reliability Data
     |
     v
Operational Performance
```

Combining delivery and runtime information helps engineering teams evaluate whether increased deployment velocity is improving or degrading service reliability.

The current project does not claim to implement a complete DORA analytics platform; this represents a natural extension of the CI/CD and observability foundations.

---

# Monitoring Responsibilities

In a real organization, observability responsibilities are typically shared.

## Platform Team

Typical responsibilities include:

* AKS monitoring foundation;
* telemetry collection;
* Log Analytics;
* cluster-level dashboards;
* common alert infrastructure;
* observability integrations.

## Application Team

Typical responsibilities include:

* application-specific telemetry;
* business and service metrics;
* application dashboards;
* service-specific alerts;
* application SLIs and SLOs.

## SRE / Operations

Typical responsibilities may include:

* reliability objectives;
* alert quality;
* error-budget policy;
* incident response;
* operational readiness;
* escalation processes;
* reliability improvement.

A platform should provide standardized observability capabilities without requiring the platform team to define every application-specific signal.

---

# Observability Maturity

The implementation can be viewed as part of a broader observability maturity path:

```text
Stage 1
Resource Visibility
        |
        v
Stage 2
Kubernetes Workload Visibility
        |
        v
Stage 3
Centralized Queryable Telemetry
        |
        v
Stage 4
Automated Detection and Alerting
        |
        v
Stage 5
Application Telemetry and Distributed Tracing
        |
        v
Stage 6
SLIs / SLOs / Error Budgets
        |
        v
Stage 7
Automated Operational Response
```

This project primarily establishes Stages 1 through 4.

The later stages represent production observability and SRE capabilities that can build on the monitoring foundation demonstrated here.

---

# Key Monitoring Takeaways

The monitoring implementation demonstrates several important platform-engineering principles.

First, observability is treated as infrastructure.

Terraform provisions monitoring resources together with the platform, making telemetry collection and alerting reproducible rather than dependent on manual portal configuration.

Second, collection, investigation, and alerting are separate concerns.

```text
Collect
   |
   v
Store
   |
   v
Query
   |
   v
Detect
   |
   v
Notify
```

Log Analytics provides centralized queryable telemetry, while Azure Monitor alert rules evaluate defined operational conditions and Action Groups provide the response integration point.

Third, Kubernetes health exists at multiple layers.

```text
Azure Platform
      |
      v
AKS
      |
      v
Node
      |
      v
Pod
      |
      v
Container
      |
      v
Application
```

Cluster availability alone does not prove application health.

Fourth, autoscaling requires observability.

Horizontal Pod Autoscaler behavior, pending workloads, resource utilization, and cluster capacity must be visible so engineers can determine whether scaling mechanisms are responding correctly.

Fifth, monitoring must ultimately support operational decisions.

The target operating model is:

```text
Collect
   |
   v
Understand
   |
   v
Detect
   |
   v
Respond
   |
   v
Recover
   |
   v
Improve
```

The objective is not simply to create monitoring resources or dashboards.

The objective is to provide engineers with sufficient telemetry and automated detection to identify failure domains, investigate problems efficiently, and restore healthy service operation.