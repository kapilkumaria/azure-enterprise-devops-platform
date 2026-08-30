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

Application workloads are deployed with explicit pod-level and container-level Kubernetes `securityContext` controls.

The implementation applies the following pod-level controls:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```
The application container applies additional runtime restrictions:

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  capabilities:
    drop:
      - ALL
```
These controls provide multiple layers of runtime hardening:

- execution as an explicit non-root UID and GID;
- privileged-container execution disabled;
- privilege escalation disabled;
- read-only container root filesystem;
- all Linux capabilities dropped;
- runtime-default seccomp filtering.

The configuration is implemented in the reusable application base and the explicit Staging and Production deployment configurations.

```
Application Pod
      |
      +--> Non-root UID/GID
      +--> RuntimeDefault seccomp
      |
      v
Application Container
      |
      +--> privileged: false
      +--> No privilege escalation
      +--> Read-only root filesystem
      +--> Drop ALL Linux capabilities
```
These controls reduce the privileges available to a compromised application process and limit the runtime attack surface.

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

The Continuous Integration pipeline validates source code, builds the application artifact, performs security analysis, publishes security evidence, and establishes artifact trust before the image becomes eligible for deployment.

The CI workflow includes:

1. application validation;
2. Trivy filesystem security scanning;
3. Docker image build;
4. Trivy container-image vulnerability scanning;
5. JSON and SARIF security-report generation;
6. CycloneDX SBOM generation;
7. security evidence publication;
8. image push to Azure Container Registry;
9. immutable image-digest resolution;
10. Notation signing using the configured Azure Key Vault-backed signing capability;
11. signature verification.

Reusable pipeline logic is maintained under:

```text
pipelines/templates/
```
The high-level flow is:

```
Source
  |
  v
Application Validation
  |
  v
Trivy Filesystem Gate
  |
  v
Docker Build
  |
  v
Trivy Image Gate
  |
  +--> JSON
  +--> SARIF
  +--> CycloneDX SBOM
  |
  v
Push to ACR
  |
  v
Resolve Image Digest
  |
  v
Notation Sign
  |
  v
Signature Verification
  |
  v
Trusted Deployment Artifact
```
Reusable templates prevent duplicated pipeline logic and allow security controls to be applied consistently across pipeline stages.

---

# Phase 21 — Filesystem Security Scan

Trivy performs repository-level security analysis before container promotion.

The reusable implementation is defined in:

```text
pipelines/templates/trivy-filesystem-scan.yml
```
The filesystem scan evaluates:

```
Scanners: vuln, misconfig, secret
Severity: HIGH, CRITICAL
Ignore unfixed findings: enabled
Failure behavior: exit code 1
```
Terraform state files, Terraform plan files, and .terraform working directories are excluded because they are generated or sensitive operational artifacts rather than source-controlled application configuration.

The scan generates JSON and SARIF reports before enforcing the security gate.

If configured HIGH or CRITICAL findings remain after filtering, Trivy exits with a non-zero status and the pipeline fails.

```
Repository
    |
    v
Trivy Filesystem Scan
    |
    +--> Vulnerabilities
    +--> Misconfigurations
    +--> Secret Detection
    |
    v
HIGH / CRITICAL Gate
    |
    +--> Pass --> Continue CI
    |
    +--> Fail --> Stop Pipeline
```
This makes source-level security validation an enforced CI control rather than an informational scan.

---

# Phase 22 — Container Image Security Scan

After the Docker image is built, Trivy independently scans the final deployable container artifact.

The reusable implementation is defined in:

```text
pipelines/templates/trivy-image-scan.yml
```
The image-security policy uses:
```
Scanner: vuln
Severity: HIGH, CRITICAL
Ignore unfixed findings: enabled
Failure behavior: exit code 1
```
Image scanning is required even after repository scanning because the built artifact can contain vulnerabilities introduced through:

- operating-system packages;
- base images;
- package-manager installations;
- transitive dependencies;
- binaries and runtime components introduced during the build.

The image scan generates:

- JSON vulnerability report;
- SARIF vulnerability report;
- CycloneDX Software Bill of Materials (SBOM).

The security gate prevents pipeline progression when configured HIGH or CRITICAL vulnerabilities remain after filtering.

```
Docker Image
     |
     v
Trivy Image Scan
     |
     +--> JSON
     +--> SARIF
     +--> CycloneDX SBOM
     |
     v
Vulnerability Gate
     |
     +--> Pass
     |
     +--> Fail Pipeline
```
This validates the artifact that will actually execute in AKS rather than relying only on source-level analysis.

---

# Phase 23 — Security Report Publication

Security-analysis results are retained as Azure DevOps pipeline artifacts.

The filesystem security scan produces:

```text
JSON
SARIF
```
The container-image security scan produces:
```
JSON
SARIF
CycloneDX SBOM
```
Artifact publication uses condition: always() so machine-readable security evidence can remain available even when an enforced Trivy gate fails.

The evidence lifecycle is:

```
Security Scan
     |
     +--> Console Results
     +--> JSON
     +--> SARIF
     +--> CycloneDX SBOM
              |
              v
     Azure DevOps Pipeline Artifacts
```
Retaining this evidence improves:

- auditability;
- troubleshooting;
- vulnerability investigation;
- historical analysis;
- software inventory analysis;
- integration with downstream security tooling.

---

# Phase 24 — Artifact Publication, Signing, and Verification

After successful build and security validation, the application image is pushed to Azure Container Registry.

The CI pipeline then resolves the immutable OCI image digest.

Using the digest rather than relying only on a mutable tag establishes an immutable artifact identity.

The artifact is subsequently signed and verified using Notation.

The relevant reusable templates include:

```text
pipelines/templates/notation-sign-verify.yml
pipelines/templates/notation-verify.yml
```
The implemented supply-chain flow is:

```
Validated Image
      |
      v
Push to ACR
      |
      v
Resolve Immutable Digest
      |
      v
Notation Signing
      |
      v
Signature Verification
      |
      v
Trusted ACR Artifact
```
The signing capability uses Azure Key Vault-backed key material rather than embedding private signing keys directly in pipeline YAML.

This adds artifact integrity and authenticity controls in addition to vulnerability scanning.

The implementation therefore establishes multiple artifact-security properties:

```
Vulnerability Validation
          +
Software Inventory (SBOM)
          +
Immutable Artifact Identity
          +
Artifact Signing
          +
Signature Verification
```
---

# Phase 25 — CD Pipeline

The Continuous Deployment pipeline promotes the validated artifact across the logical application environments:

```text
Development
     |
     v
Staging
     |
     v
Production Authorization
     |
     v
Production
```
The deployment model follows a build-once, promote-the-same-artifact strategy.

The container artifact is not rebuilt separately for Development, Staging, and Production.

Instead, the trusted artifact produced by CI is promoted through the environments.

The CD workflow also performs artifact signature verification before deployment, providing an additional software supply-chain trust check.

Conceptually:
```
CI
 |
 v
Signed Immutable Artifact
 |
 v
CD Signature Verification
 |
 v
Development
 |
 v
Staging
 |
 v
Production Approval
 |
 v
Production
```
Deployment logic is implemented through reusable and parameterized Azure DevOps YAML rather than independent manually maintained deployment processes for each environment.

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

After Production authorization, the same validated and trusted artifact is deployed using the Production-specific Kubernetes configuration.

The final promotion model is:

```text
Build Once
    |
    v
Security Validate
    |
    v
Generate SBOM
    |
    v
Push to ACR
    |
    v
Sign Artifact
    |
    v
Development
    |
    v
Staging
    |
    v
Production Approval
    |
    v
Production
```
This approach avoids environment-specific image rebuilds and reduces the risk that Production receives an artifact different from the one validated earlier in the delivery lifecycle.

---

# Phase 30 — Azure Monitor and Log Analytics

The Terraform monitoring module provisions the Azure-native observability foundation together with the platform infrastructure.

Implemented monitoring resources include:

* Log Analytics Workspace;
* Data Collection Rule;
* Data Collection Rule association;
* AKS diagnostic settings;
* Azure Monitor scheduled query alert;
* Azure Monitor Action Group.

The telemetry architecture is:

```text
AKS
 |
 +--> Workload Telemetry
 +--> Container Telemetry
 +--> Platform Diagnostics
 |
 v
Collection / Diagnostic Configuration
 |
 v
Log Analytics Workspace
 |
 +--> KQL Investigation
 +--> Container Insights
 +--> Scheduled Query Evaluation
 |
 v
Azure Monitor
 |
 v
Action Group
```
Provisioning monitoring through Terraform ensures that observability configuration is reproducible and evolves together with the infrastructure.

---

# Phase 31 — Container Insights and Operational Visibility

Azure Monitor Container Insights provides Kubernetes-specific observability for AKS.

The monitoring integration provides visibility into Kubernetes infrastructure and workload information including:

* cluster state;
* nodes;
* controllers;
* pods;
* containers;
* resource utilization;
* workload health.

Operational validation also uses native Kubernetes commands such as:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployments -A
kubectl get hpa -A
kubectl top nodes
kubectl top pods -A
```
Azure-native monitoring and Kubernetes-native inspection complement one another.

Centralized telemetry provides historical investigation and alerting, while kubectl provides immediate runtime inspection.

---

# Phase 32 — Scheduled Query Alerting

The platform provisions an Azure Monitor scheduled query alert through Terraform.

The alert evaluates telemetry stored in Log Analytics to detect defined unhealthy workload conditions.

The implemented path is:

```text
AKS Condition
      |
      v
Telemetry Collection
      |
      v
Log Analytics
      |
      v
Scheduled KQL Evaluation
      |
      +--> Healthy --> No Alert
      |
      +--> Unhealthy
              |
              v
        Azure Monitor Alert
              |
              v
          Action Group
```
This converts collected observability data into an actionable operational signal instead of requiring engineers to continuously inspect logs manually.

The monitoring design separates:
```
Collection
    |
    v
Investigation
    |
    v
Detection
    |
    v
Response Integration
```
This provides a foundation for more advanced production observability such as service-level indicators, service-level objectives, managed Prometheus, Grafana, OpenTelemetry, and error-budget monitoring.

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

The high-level implementation dependency graph is:

```text
Terraform Backend
       |
       v
Resource Group
       |
       v
Networking
       |
       +-------------------------+
       |                         |
       v                         v
Managed Identities              ACR
       |                         |
       v                         |
Key Vault                       |
       |                         |
       +------------+------------+
                    |
                    v
                   AKS
                    |
          +---------+---------+
          |                   |
          v                   v
        RBAC              Monitoring
          |                   |
          v                   +--> Log Analytics
   OIDC / Federation          +--> DCR
          |                   +--> Diagnostics
          v                   +--> Alerts
 Kubernetes Platform          +--> Action Group
          |
          v
  Application Base
          |
          v
Environment Configuration

Application Source
       |
       v
      CI
       |
       +--> Security Scanning
       +--> SBOM
       +--> ACR
       +--> Signing
       |
       v
Trusted Artifact
       |
       v
      CD
       |
       v
Dev --> Staging --> Approval --> Production
```

The graph contains both infrastructure dependencies and software-delivery dependencies.

Understanding these relationships is important when troubleshooting because a failure in one layer may prevent downstream components from operating even when their own configuration is correct.

---

# Validation Strategy

Each implementation layer is validated before the platform is considered operational.

Validation is performed at infrastructure, cloud-resource, Kubernetes, security, delivery, identity, and observability layers.

## Terraform Validation

Typical checks include:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```
Terraform configuration should be syntactically valid and the resulting plan should be reviewed before infrastructure changes are applied.

## Azure Resource Validation

Typical checks include:
```bash
az resource list
az aks show
az acr show
az keyvault show
```
These checks confirm that the expected Azure resources exist and expose the required configuration.

## Kubernetes Validation

Typical checks include:
```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployments -A
kubectl get hpa -A
kubectl get serviceaccounts -A
```
Additional runtime inspection can include:
```bash
kubectl top nodes
kubectl top pods -A
```
## Deployment Validation

Application rollout is explicitly validated:
```bash
kubectl rollout status deployment/<deployment> -n <namespace>
```
A successful kubectl apply is not considered sufficient evidence of a healthy deployment.

## Identity and Secret Validation

The running application is validated to ensure that:

- the expected ServiceAccount is used;
- Workload Identity federation succeeds;
- no static Azure client secret is required by the pod;
- Key Vault secret access succeeds through the intended identity path;
- Secrets Store CSI integration functions correctly.

## Security Validation

The delivery workflow validates:

- Trivy filesystem security gate;
- Trivy image vulnerability gate;
- JSON/SARIF report generation;
- CycloneDX SBOM generation;
- artifact publication;
- immutable image-digest resolution;
- Notation signing;
- signature verification;
- hardened Kubernetes securityContext.

## Monitoring Validation

Operational validation confirms:

- AKS telemetry reaches the monitoring platform;
- Log Analytics contains queryable telemetry;
- Container Insights provides Kubernetes visibility;
- scheduled query alert configuration exists;
- the Action Group response path is configured;
- Kubernetes HPA and workload state can be inspected.

This layered validation strategy is important because successful infrastructure provisioning alone does not prove that the complete platform works.

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

# Implementation Evidence Strategy

Portfolio evidence is captured from the rebuilt and validated environment so screenshots represent the actual implemented platform rather than isolated configuration fragments.

The evidence workflow is:

```text
Recreate Infrastructure
        |
        v
Start Self-Hosted Agent
        |
        v
Validate Azure / AKS
        |
        v
Execute CI
        |
        v
Execute CD
        |
        v
Validate Dev / Staging / Production
        |
        v
Validate Security Controls
        |
        v
Validate Monitoring
        |
        v
Capture Evidence
        |
        v
Sanitize Screenshots
        |
        v
Publish Documentation
```
Evidence is selected to demonstrate operational capabilities such as successful pipelines, workload identity, security gates, runtime hardening, observability, autoscaling, and controlled Production promotion.

Screenshots are reviewed before publication to ensure that passwords, tokens, private keys, secret values, sensitive Terraform outputs, and other credentials are not exposed.

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

The completed platform integrates:

* Terraform Infrastructure as Code;
* Microsoft Azure;
* Azure Kubernetes Service;
* Azure Container Registry;
* Azure Key Vault;
* Microsoft Entra Workload Identity;
* OIDC federation;
* Azure RBAC;
* Kubernetes;
* Kustomize;
* Kubernetes HPA;
* AKS Cluster Autoscaler;
* Kubernetes runtime hardening;
* Secrets Store CSI integration;
* Azure DevOps CI/CD;
* reusable pipeline templates;
* Docker;
* Trivy filesystem security scanning;
* Trivy container-image scanning;
* JSON and SARIF security evidence;
* CycloneDX SBOM generation;
* immutable container-image digests;
* Notation artifact signing and verification;
* Azure Monitor;
* Log Analytics;
* Container Insights;
* scheduled query alerting;
* Azure Monitor Action Groups;
* Development → Staging → Production promotion;
* Production approval governance;
* remote Terraform state;
* Terraform backend network hardening.

The significant outcome is not the number of technologies used.

The platform demonstrates how infrastructure provisioning, Kubernetes, identity, secrets management, CI/CD, DevSecOps, software supply-chain security, observability, autoscaling, and release governance can operate together as one coherent engineering system.

---

# Key Implementation Takeaways

Several engineering lessons emerge from the implementation.

First, **dependency order matters**.

Networking, identities, role assignments, AKS, federation, Kubernetes resources, and application workloads depend on one another. Infrastructure should therefore be assembled and validated in deliberate layers.

Second, **identity should replace static credentials wherever practical**.

Microsoft Entra Workload Identity and AKS OIDC federation allow application workloads to access Azure resources without embedding persistent Azure client secrets inside Kubernetes manifests.

Third, **security belongs inside the delivery lifecycle**.

Repository scanning, image scanning, enforced vulnerability gates, security evidence, SBOM generation, artifact signing, signature verification, and runtime hardening operate as complementary controls rather than isolated security products.

Fourth, **build once and promote the same artifact**.

Development, Staging, and Production should receive the same validated container artifact rather than independently rebuilt images. Immutable image identity and signature verification strengthen this promotion model.

Fifth, **runtime security remains necessary even after a clean vulnerability scan**.

Non-root execution, disabled privilege escalation, read-only root filesystems, dropped Linux capabilities, and seccomp filtering reduce the privileges available to a compromised workload.

Sixth, **observability is infrastructure**.

Log Analytics, Container Insights, Data Collection Rules, diagnostic settings, alert rules, and Action Groups are provisioned alongside the platform rather than added manually after deployment.

Seventh, **successful provisioning is not the same as successful operation**.

Terraform apply, Kubernetes manifest application, CI completion, deployment rollout, workload identity, secret retrieval, security controls, and monitoring all require independent validation.

Finally, **reproducibility is one of the strongest tests of Infrastructure as Code**.

A platform that can be destroyed and recreated from version-controlled Terraform, Kubernetes configuration, and pipeline definitions is substantially less dependent on undocumented manual configuration.

The resulting engineering lifecycle is:

```text
Define
  |
  v
Provision
  |
  v
Secure
  |
  v
Build
  |
  v
Validate
  |
  v
Sign
  |
  v
Promote
  |
  v
Observe
  |
  v
Operate
  |
  v
Recreate
```
That lifecycle represents the central implementation objective of the Azure Enterprise DevOps Platform.

