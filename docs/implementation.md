# Azure Enterprise DevOps Platform — Implementation Guide

## Overview

This document explains how the Azure Enterprise DevOps Platform is assembled from infrastructure, Kubernetes, identity, CI/CD, security, and monitoring components.

The goal is not to provide only a command list.

The implementation is organized around dependency order so that each layer is created only after the services it depends on are available.

The overall sequence is:

```text
Terraform Backend
      |
      v
Azure Networking
      |
      v
Managed Identities
      |
      v
ACR / Key Vault
      |
      v
AKS
      |
      v
RBAC
      |
      v
Workload Identity
      |
      v
Kubernetes Platform Resources
      |
      v
Application Workloads
      |
      v
CI/CD
      |
      v
Monitoring and Alerting
```

---

# Implementation Principles

The implementation follows several principles:

* infrastructure first;
* dependencies before consumers;
* reusable Terraform modules;
* declarative Kubernetes configuration;
* workload identity instead of static credentials;
* CI/CD as code;
* environment promotion;
* security integrated into CI;
* monitoring provisioned with infrastructure;
* reproducible lifecycle management.

---

# Repository Layout

The repository is divided by responsibility.

```text
application/
terraform/
kubernetes/
pipelines/
docs/
diagrams/
monitoring/
security/
scripts/
```

Each directory represents a distinct engineering concern.

---

# Phase 1 — Terraform Backend Bootstrap

The Terraform backend is created separately from the main workload infrastructure.

The bootstrap configuration is located under:

```text
terraform/bootstrap/
```

The purpose of separating bootstrap infrastructure is to avoid creating a circular dependency where Terraform attempts to destroy the backend storing its own state.

The lifecycle is:

```text
Bootstrap Terraform
        |
        v
Remote Backend
        |
        v
Environment Terraform
```

The backend remains available even when the AKS platform is destroyed.

---

# Phase 2 — Terraform Environment Initialization

The primary environment configuration is located under:

```text
terraform/environments/dev/
```

Typical initialization steps include:

```bash
cd terraform/environments/dev
terraform init
terraform validate
terraform plan
```

Terraform initializes the remote backend and loads the reusable modules required by the environment.

---

# Phase 3 — Resource Group

The Azure Resource Group provides the administrative boundary for the platform resources.

The development platform uses a dedicated resource group.

Terraform owns the lifecycle of the Resource Group together with the resources deployed inside it.

---

# Phase 4 — Networking

The networking module creates:

* Azure Virtual Network;
* AKS subnet;
* private endpoint subnet.

The networking resources are created before AKS because the cluster depends on the target subnet.

The dependency flow is:

```text
VNet
 |
 +--> AKS Subnet
 |
 +--> Private Endpoint Subnet
```

The AKS control-plane identity later receives the required subnet permissions.

---

# Phase 5 — Managed Identities

The identity module provisions separate User Assigned Managed Identities.

The main responsibilities are separated into:

```text
AKS Control Plane Identity
        |
        +--> Azure infrastructure operations

Application Workload Identity
        |
        +--> Application access to Azure resources
```

This separation reduces unnecessary permission sharing between infrastructure and application workloads.

---

# Phase 6 — Azure Container Registry

Azure Container Registry is provisioned as the private container registry.

The registry stores images created by CI.

The application image lifecycle is:

```text
Source
  |
  v
CI Build
  |
  v
ACR
  |
  v
AKS
```

AKS receives permission to pull from the registry through Azure RBAC.

---

# Phase 7 — Azure Key Vault

Azure Key Vault provides centralized application secret storage.

The workload identity receives only the Key Vault permissions required by the application.

Application credentials are therefore not embedded directly in Kubernetes configuration.

---

# Phase 8 — AKS

The AKS Terraform module provisions the Kubernetes platform.

Key capabilities include:

* managed Kubernetes control plane;
* system node pool;
* user node pool;
* cluster autoscaling;
* OIDC issuer;
* Microsoft Entra Workload Identity;
* Azure RBAC integration;
* monitoring integration.

The cluster provides the runtime for all application environments.

---

# Phase 9 — System and User Node Pools

The AKS platform separates system workloads and application workloads.

Conceptually:

```text
AKS
 |
 +--> System Node Pool
 |       |
 |       +--> Kubernetes critical services
 |
 +--> User Node Pool
         |
         +--> Application workloads
```

This reduces competition between application pods and cluster-critical components.

---

# Phase 10 — Azure RBAC

Role assignments are created after the target identities and resources exist.

Important examples include:

```text
AKS Identity
      |
      +--> Network Contributor
              |
              v
          AKS Subnet
```

```text
AKS
 |
 +--> AcrPull
        |
        v
       ACR
```

```text
Workload Identity
       |
       +--> Key Vault Secrets User
                    |
                    v
                Key Vault
```

These assignments are scoped to the resources that require access.

---

# Phase 11 — OIDC and Workload Identity

AKS is configured with OIDC and Workload Identity enabled.

The authentication path is:

```text
Pod
 |
 v
Kubernetes ServiceAccount
 |
 v
AKS OIDC Issuer
 |
 v
Federated Identity Credential
 |
 v
Azure Managed Identity
```

This removes the need for a static Azure client secret inside the workload.

---

# Phase 12 — Federated Identity Credentials

Federated Identity Credentials establish trust between Kubernetes ServiceAccounts and the Azure workload managed identity.

Environment-specific credentials are created for:

* Development;
* Staging;
* Production.

The trust relationship includes:

* AKS OIDC issuer;
* namespace;
* ServiceAccount;
* managed identity.

This provides identity-aware environment separation.

---

# Phase 13 — Kubernetes Platform Resources

The platform-level Kubernetes configuration is stored under:

```text
kubernetes/platform/
```

Platform resources include:

```text
key-vault-csi/
workload-identity/
```

These establish the Kubernetes-side resources required before application workloads consume Azure identity and secrets.

---

# Phase 14 — Kubernetes Base Application

The reusable application manifests are stored under:

```text
kubernetes/base/application/
```

The base contains:

* Deployment;
* Service;
* Horizontal Pod Autoscaler;
* Kustomization.

The base defines common application behavior without environment-specific duplication.

---

# Phase 15 — Kustomize Environment Overlays

Environment-specific configuration is maintained under:

```text
kubernetes/overlays/
├── dev
├── staging
└── prod
```

The overlays allow differences in:

* namespace;
* ServiceAccount;
* replica configuration;
* HPA configuration;
* secret provider references;
* environment-specific settings.

The base remains reusable.

---

# Phase 16 — Kubernetes ServiceAccounts

Each environment uses an appropriate Kubernetes ServiceAccount.

The ServiceAccount participates in Workload Identity federation.

The identity chain is:

```text
Application Pod
      |
      v
ServiceAccount
      |
      v
OIDC Federation
      |
      v
Managed Identity
```

---

# Phase 17 — SecretProviderClass

SecretProviderClass resources define how Kubernetes workloads consume external secrets from Azure Key Vault.

The secret access path is:

```text
Pod
 |
 v
ServiceAccount
 |
 v
Workload Identity
 |
 v
Azure Key Vault
 |
 v
Secrets Store CSI
 |
 v
Application
```

The application therefore consumes external secret material without storing Azure credentials.

---

# Phase 18 — Kubernetes Workload Hardening

The application Deployment is configured with explicit security controls.

The workload is hardened to avoid unnecessary root execution and privilege.

SecurityContext settings reduce runtime privilege and improve defense in depth.

---

# Phase 19 — Horizontal Pod Autoscaling

The application includes Kubernetes Horizontal Pod Autoscaler resources.

HPA allows application replicas to scale according to configured resource metrics.

Conceptually:

```text
Application Load
       |
       v
HPA
       |
       v
Replica Increase
```

This works together with AKS node autoscaling.

---

# Phase 20 — CI Pipeline

The Continuous Integration pipeline validates and produces the application artifact.

The pipeline includes:

1. application validation;
2. Trivy filesystem scan;
3. Docker build;
4. Trivy image scan;
5. security report generation;
6. artifact publication;
7. image push to ACR.

Reusable YAML templates are stored under:

```text
pipelines/templates/
```

This prevents duplicated pipeline logic.

---

# Phase 21 — Filesystem Security Scan

Trivy scans the repository before the container image reaches deployment.

The scan is part of the pipeline gate.

Known unacceptable findings can stop the pipeline before artifact promotion.

---

# Phase 22 — Container Image Security Scan

After the Docker image is created, the final image is scanned independently.

This validates the actual deployable artifact, including operating-system packages and dependencies introduced during image creation.

---

# Phase 23 — Security Report Publication

Security scan results are published as Azure DevOps pipeline artifacts.

The project retains machine-readable evidence such as:

```text
JSON
SARIF
```

This makes scan results available for later review and audit.

---

# Phase 24 — Container Image Publication

After successful validation, the trusted application image is stored in Azure Container Registry.

The image becomes the artifact promoted through the deployment pipeline.

---

# Phase 25 — CD Pipeline

The Continuous Deployment pipeline promotes the validated artifact across:

```text
Development
     |
     v
Staging
     |
     v
Production
```

Deployment logic is reusable and parameterized.

---

# Phase 26 — Development Deployment

The Development stage performs the first runtime deployment.

Validation should confirm:

* pods start successfully;
* deployment rollout succeeds;
* image pull succeeds;
* Key Vault integration works;
* Workload Identity works;
* Service and HPA resources are healthy.

---

# Phase 27 — Staging Promotion

After Development validation, the same application artifact is promoted into Staging.

The objective is to validate the release in a stronger pre-production boundary without rebuilding the application image.

---

# Phase 28 — Production Approval

Production promotion includes an approval boundary.

This introduces release governance between Staging and Production.

The production deployment does not occur merely because the previous stage succeeded.

---

# Phase 29 — Production Deployment

After approval, the validated artifact is deployed to the Production namespace using its environment-specific Kubernetes configuration.

The final release path is:

```text
Build Once
   |
   v
Dev
   |
   v
Staging
   |
   v
Approval
   |
   v
Production
```

---

# Phase 30 — Azure Monitor and Log Analytics

The monitoring module provisions the Azure-native observability foundation.

Resources include:

* Log Analytics Workspace;
* Data Collection Rule;
* DCR association;
* AKS diagnostic settings;
* Azure Monitor alert rule;
* Action Group.

Monitoring is provisioned as code together with the platform.

---

# Phase 31 — Container Insights

Container Insights provides AKS workload and infrastructure visibility.

It allows engineers to inspect:

* nodes;
* controllers;
* pods;
* containers;
* resource utilization;
* Kubernetes health.

---

# Phase 32 — Scheduled Query Alerting

The platform includes an Azure Monitor scheduled query rule for unhealthy application pod conditions.

The flow is:

```text
AKS Telemetry
      |
      v
Log Analytics
      |
      v
Scheduled Query
      |
      v
Alert Rule
      |
      v
Action Group
```

---

# Phase 33 — Terraform Backend Hardening

The Terraform backend storage networking is restricted.

The security model includes:

* default network deny;
* explicitly authorized administrator public IP;
* required Azure service bypass behavior.

This reduces broad network exposure of Terraform state infrastructure.

---

# Phase 34 — Source-Control Hardening

The repository `.gitignore` protects sensitive and generated files.

Excluded content includes:

* Terraform state;
* Terraform plan files;
* real Terraform variable files;
* private keys;
* kubeconfig files;
* environment files;
* temporary files.

Sanitized examples remain available for documentation and reproducibility.

---

# Phase 35 — Infrastructure Lifecycle Validation

The environment is intentionally designed to support destruction and recreation.

The lifecycle is:

```text
terraform apply
      |
      v
Running Platform
      |
      v
Validation
      |
      v
terraform destroy
      |
      v
Environment Removed
```

Later, Terraform can recreate the platform from source-controlled infrastructure definitions.

This proves that the environment does not depend on undocumented manual portal configuration.

---

# Dependency Map

The high-level dependency graph is:

```text
Backend
  |
  v
Resource Group
  |
  v
Networking
  |
  +--------------------+
  |                    |
  v                    v
Identities            ACR
  |                    |
  v                    |
Key Vault              |
  |                    |
  +---------+----------+
            |
            v
           AKS
            |
            v
           RBAC
            |
            v
     Federated Identity
            |
            v
     Kubernetes Platform
            |
            v
      Application Base
            |
            v
   Environment Overlays
            |
            v
          CI/CD
            |
            v
       Monitoring
```

Understanding this dependency order is important when troubleshooting provisioning failures.

---

# Validation Strategy

Each implementation layer should be validated before proceeding.

## Terraform Validation

Typical checks include:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

## Azure Validation

Typical checks include:

```bash
az resource list
az aks show
az acr show
az keyvault show
```

## Kubernetes Validation

Typical checks include:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployments -A
kubectl get hpa -A
kubectl get serviceaccounts -A
```

## Deployment Validation

Typical checks include:

```bash
kubectl rollout status deployment/<deployment> -n <namespace>
```

A successful manifest application is not considered sufficient without runtime validation.

---

# Rebuild Workflow

After a complete Terraform destroy, the platform can be recreated.

A high-level rebuild sequence is:

```bash
cd terraform/environments/dev

terraform init
terraform validate
terraform plan
terraform apply
```

After infrastructure creation:

```text
Retrieve AKS Credentials
        |
        v
Validate Cluster
        |
        v
Run CI
        |
        v
Run CD
        |
        v
Dev
        |
        v
Staging
        |
        v
Production
```

This rebuild capability is an important part of the project's Infrastructure as Code design.

---

# Self-Hosted Agent Lifecycle

The Azure DevOps self-hosted agent runs on AWS EC2.

For cost control, the agent does not need to remain running continuously in the portfolio environment.

Typical lifecycle:

```text
Start EC2
    |
    v
Agent Online
    |
    v
Run Pipelines
    |
    v
Validation Complete
    |
    v
Stop EC2
```

The agent should be available before CI/CD jobs requiring that pool are executed.

---

# Cost Management

The platform is intentionally operated as an ephemeral portfolio environment.

High-cost resources such as AKS worker nodes and the EC2 self-hosted agent are shut down or destroyed when not required.

The operating model is:

```text
Need Demonstration
      |
      v
Recreate / Start
      |
      v
Validate
      |
      v
Capture Evidence
      |
      v
Destroy / Stop
```

This keeps the portfolio architecture realistic without paying continuously for unused infrastructure.

---

# Screenshot Collection Strategy

Screenshots should be captured only after the final README and detailed documentation define what evidence is required.

This avoids collecting large numbers of low-value portal screenshots.

The evidence session should follow:

```text
Rebuild Azure
      |
      v
Start AWS Agent
      |
      v
Run Final CI
      |
      v
Run Final CD
      |
      v
Validate Platform
      |
      v
Capture Required Evidence
      |
      v
Commit Screenshots
      |
      v
Destroy Azure
      |
      v
Stop AWS Agent
```

---

# Operational Handoff

A production platform should provide engineers with enough documentation to:

* recreate infrastructure;
* validate cluster health;
* identify pipeline failures;
* inspect security findings;
* troubleshoot workload identity;
* inspect Key Vault integration;
* investigate monitoring alerts;
* safely destroy non-production infrastructure.

The documentation under `docs/` is intended to provide that operational context.

---

# Implementation Outcomes

The final platform demonstrates an integrated implementation of:

* Terraform;
* Azure;
* AKS;
* ACR;
* Key Vault;
* Workload Identity;
* OIDC federation;
* Kubernetes;
* Kustomize;
* Azure DevOps;
* Docker;
* Trivy;
* Azure Monitor;
* Log Analytics;
* autoscaling;
* environment promotion;
* production governance.

The significant outcome is not the number of technologies used.

The outcome is that these technologies operate together as a coherent delivery platform.

---

# Key Implementation Takeaways

Several implementation lessons are important.

First, dependency order matters.

Networking, identities, RBAC, and Kubernetes identity relationships must be created in the correct sequence.

Second, security should be integrated during implementation rather than added at the end.

Third, workload identity removes an entire class of static credential-management problems.

Fourth, environment promotion is easier to reason about when the same container artifact is promoted rather than rebuilt.

Fifth, monitoring should be created with the infrastructure rather than manually added after deployment.

Finally, reproducibility is the strongest test of Infrastructure as Code.

If the platform can be destroyed and recreated from the repository, the implementation is much less dependent on undocumented manual configuration.

