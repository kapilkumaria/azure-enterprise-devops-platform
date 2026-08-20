# Azure Enterprise DevOps Platform — Troubleshooting Guide

## Overview

This document records troubleshooting patterns, implementation problems, root causes, fixes, and engineering lessons from building the Azure Enterprise DevOps Platform.

The platform combines multiple systems:

* Terraform
* Microsoft Azure
* Azure Kubernetes Service
* Azure Container Registry
* Azure Key Vault
* Microsoft Entra Workload Identity
* Kubernetes
* Kustomize
* Azure DevOps
* Docker
* Trivy
* Notation
* Azure Monitor
* Log Analytics
* an AWS EC2 self-hosted Azure DevOps agent

Because these systems interact across cloud, identity, networking, Kubernetes, CI/CD, and security boundaries, troubleshooting requires identifying the layer where a failure actually originates.

The general troubleshooting model used throughout the project is:

```text
Observe Symptom
      |
      v
Identify Failure Layer
      |
      v
Collect Evidence
      |
      v
Form Hypothesis
      |
      v
Test Smallest Change
      |
      v
Validate Result
      |
      v
Document Root Cause
```

The objective is not simply to make an error disappear.

The objective is to understand why the failure occurred and ensure the solution remains reproducible.

---

# Troubleshooting Principles

Several principles were used throughout the project.

## Start With the Failure Boundary

The first question should be:

> Which system is actually failing?

For example:

```text
Pipeline Failure
      |
      +--> Azure DevOps?
      +--> Self-hosted agent?
      +--> Docker?
      +--> ACR authentication?
      +--> AKS authentication?
      +--> Kubernetes manifest?
      +--> Workload Identity?
      +--> Application?
```

A failed Azure DevOps pipeline does not necessarily mean Azure DevOps itself is the problem.

The pipeline may simply be exposing a failure in another system.

---

## Validate One Layer at a Time

The platform was validated incrementally.

For Terraform:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

For Azure:

```bash
az account show
az resource list
az aks show
az acr show
az keyvault show
```

For Kubernetes:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployments -A
kubectl get hpa -A
```

For application rollout:

```bash
kubectl rollout status deployment/<deployment> -n <namespace>
```

This prevents multiple unknown failures from being investigated simultaneously.

---

# Troubleshooting Layers

The platform can be divided into the following troubleshooting domains:

```text
Layer 1  Terraform
Layer 2  Azure Resource Provisioning
Layer 3  Azure Networking
Layer 4  Azure RBAC
Layer 5  AKS
Layer 6  Kubernetes
Layer 7  Workload Identity
Layer 8  Key Vault
Layer 9  Container Registry
Layer 10 Azure DevOps
Layer 11 Self-Hosted Agent
Layer 12 Container Security
Layer 13 Monitoring
Layer 14 Software Supply Chain
```

Understanding the boundaries between these layers is essential for efficient diagnosis.

---

# Issue 1 — Terraform State Must Not Be Stored in Git

## Problem

Terraform creates local state artifacts such as:

```text
terraform.tfstate
terraform.tfstate.backup
```

Terraform plan files may also be generated:

```text
tfplan
*.tfplan
```

These files should not be committed to a public repository.

Terraform state may contain detailed infrastructure metadata and potentially sensitive values.

---

## Risk

Committing Terraform state creates several problems:

* sensitive infrastructure information may become public;
* state history remains in Git;
* developers can accidentally work against stale state;
* multiple engineers may create conflicting local state;
* repository history becomes polluted with generated state data.

---

## Resolution

The project uses remote Terraform state and excludes local state artifacts through `.gitignore`.

Relevant patterns include:

```text
*.tfstate
*.tfstate.*
*.tfplan
*.tfplan.*
tfplan
```

Tracked files were checked with:

```bash
git ls-files | grep -E \
'(^|/)(terraform\.tfstate|terraform\.tfstate\.backup|tfplan)$'
```

Expected result:

```text
no output
```

---

## Validation

The repository can be checked with:

```bash
git status
```

and:

```bash
git ls-files | grep tfstate
```

No real Terraform state should be tracked.

---

## Engineering Lesson

`.gitignore` is not merely repository housekeeping.

For Infrastructure as Code, it is part of the security boundary.

Generated state, credentials, private keys, and environment-specific configuration require deliberate source-control protection.

---

# Issue 2 — Terraform Variable Files Must Be Protected

## Problem

Terraform variable files can contain environment-specific values and potentially sensitive information.

Files such as:

```text
terraform.tfvars
*.auto.tfvars
```

should not automatically be committed.

---

## Resolution

The repository excludes real variable files:

```text
*.tfvars
*.tfvars.json
*.auto.tfvars
*.auto.tfvars.json
```

while allowing sanitized examples:

```text
!*.example.tfvars
!*.tfvars.example
```

This allows the repository to remain reproducible without publishing real environment configuration.

---

## Engineering Lesson

A public infrastructure repository should show users **what configuration is required** without exposing **the actual operational values**.

Example files are therefore preferable to real environment files.

---

# Issue 3 — Terraform Backend Network Hardening

## Problem

The Terraform remote-state backend initially required stronger network restrictions.

Terraform state is security-sensitive and should not be unnecessarily reachable from arbitrary public networks.

---

## Security Objective

The desired model was:

```text
Public Internet
      |
      X
      |
Terraform Backend


Authorized Administrator
      |
      v
Terraform Backend


Required Azure Services
      |
      v
Terraform Backend
```

---

## Resolution

The backend storage networking was hardened using:

* default network action set to Deny;
* explicit administrator public IP allowance;
* AzureServices bypass where required.

This significantly reduces the exposed network surface of the Terraform state backend.

---

## Important Operational Consideration

Network hardening can also block Terraform itself if the workstation or execution agent is no longer within an allowed network path.

When backend initialization unexpectedly fails after network-policy changes, check:

1. current public IP;
2. storage account firewall configuration;
3. allowed network rules;
4. Azure service bypass configuration;
5. whether the backend can still be reached from the Terraform execution environment.

---

## Engineering Lesson

Security controls can affect automation availability.

The correct approach is not to disable the security control when automation breaks.

The correct approach is to identify the required trusted network path and explicitly authorize it.

---

# Issue 4 — Terraform State Locking

## Symptom

Terraform operations may display:

```text
Acquiring state lock...
```

or:

```text
Releasing state lock...
```

State locking protects against concurrent state modification.

---

## Investigation

If Terraform appears blocked, determine whether:

* another Terraform operation is running;
* a previous operation terminated unexpectedly;
* the remote backend still believes the state is locked.

Do not immediately force-unlock state.

---

## Safe Approach

First verify that no legitimate Terraform operation is active.

Only then consider:

```bash
terraform force-unlock <LOCK_ID>
```

---

## Engineering Lesson

Terraform state locking is a safety mechanism, not an inconvenience.

Forcing an unlock without understanding the active state owner can corrupt infrastructure state.

---

# Issue 5 — Correct Terraform Working Directory

## Problem

The repository contains multiple Terraform layers:

```text
terraform/bootstrap/
terraform/environments/dev/
terraform/environments/staging/
terraform/environments/prod/
terraform/modules/
```

Terraform commands must be executed from the correct root module.

For the active development environment, the working directory is:

```bash
cd terraform/environments/dev
```

---

## Why This Matters

Running:

```bash
terraform plan
```

from the wrong directory can produce:

* missing backend configuration;
* missing variables;
* incorrect provider configuration;
* unrelated plans;
* module-resolution problems.

---

## Validation

Always check:

```bash
pwd
```

before destructive or infrastructure-changing operations.

For example:

```text
/home/kapil/Projects/azure-enterprise-devops-platform/terraform/environments/dev
```

---

## Engineering Lesson

Before `apply` or `destroy`, always verify:

```text
Working Directory
Subscription
Terraform Workspace / State
Planned Resources
```

A correct command executed in the wrong environment can be more dangerous than an incorrect command.

---

# Issue 6 — Understanding Terraform Destroy Before Execution

## Situation

Before destroying the development platform, Terraform showed:

```text
Plan: 0 to add, 0 to change, 24 to destroy.
```

The state contained resources including:

* Resource Group;
* ACR;
* AKS;
* user node pool;
* managed identities;
* Key Vault;
* Log Analytics;
* Data Collection Rule;
* diagnostic settings;
* alerting resources;
* VNet;
* subnets;
* federated identity credentials;
* Azure RBAC assignments.

---

## Correct Validation

Before executing a destructive operation:

```bash
terraform plan -destroy
```

Review the plan carefully.

Then:

```bash
terraform state list
```

Confirm that Terraform owns the resources you expect to remove.

Only after validation should:

```bash
terraform destroy
```

be executed.

---

## Engineering Lesson

`terraform destroy` should never be treated as routine cleanup without reviewing scope.

The plan is the change-control document for the operation.

---

# Issue 7 — AKS Requires Correct Network Permissions

## Problem Domain

AKS uses an Azure subnet created separately by Terraform.

The AKS managed identity requires appropriate Azure permissions to perform required networking operations.

Without the correct role assignment, AKS provisioning or network operations can fail.

---

## Required Relationship

Conceptually:

```text
AKS Control Plane Managed Identity
             |
             | Network Contributor
             v
         AKS Subnet
```

---

## Resolution

Terraform creates an Azure RBAC assignment granting the required networking role at the subnet scope.

The important principle is scope.

The identity does not require broad subscription-level Contributor access merely to operate within the AKS subnet.

---

## Validation

Azure role assignments can be inspected with:

```bash
az role assignment list \
  --scope <AKS_SUBNET_RESOURCE_ID> \
  --output table
```

---

## Engineering Lesson

When an Azure resource reports an authorization failure, identify:

```text
WHO
needs to perform
WHAT ACTION
against
WHICH RESOURCE
```

Then assign the narrowest role at the narrowest appropriate scope.

---

# Issue 8 — AKS Must Be Able to Pull Images From ACR

## Problem Domain

Creating ACR and AKS does not automatically mean Kubernetes can retrieve private container images.

AKS needs authorization to pull from ACR.

---

## Required Relationship

```text
AKS
 |
 | AcrPull
 v
ACR
```

---

## Symptoms of Failure

A Kubernetes pod may show:

```text
ImagePullBackOff
```

or:

```text
ErrImagePull
```

---

## Investigation

Check:

```bash
kubectl describe pod <pod> -n <namespace>
```

Then inspect:

```text
Events
```

Possible causes include:

* incorrect image name;
* incorrect tag;
* missing image;
* ACR authentication failure;
* missing AcrPull assignment.

---

## Resolution

Terraform manages the appropriate ACR pull role assignment.

---

## Engineering Lesson

`ImagePullBackOff` is a Kubernetes symptom.

The root cause may exist in:

* registry configuration;
* Azure RBAC;
* image naming;
* CI artifact publication.

Always trace the entire image path.

---

# Issue 9 — Workload Identity Requires Multiple Components

## Problem

Enabling Workload Identity on AKS is not sufficient by itself.

Successful federation requires several components to agree.

---

## Required Chain

```text
AKS OIDC Issuer
      |
      v
Kubernetes ServiceAccount
      |
      v
Federated Identity Credential
      |
      v
Azure Managed Identity
      |
      v
Azure Resource
```

If one component is incorrect, authentication fails.

---

## Components to Validate

Check:

1. AKS OIDC issuer enabled;
2. Workload Identity enabled;
3. ServiceAccount namespace;
4. ServiceAccount name;
5. ServiceAccount annotation/configuration;
6. federated credential subject;
7. federated credential issuer;
8. managed identity client ID;
9. Azure RBAC permissions.

---

## AKS Validation

```bash
az aks show \
  --resource-group <resource-group> \
  --name <aks-name> \
  --query "{oidc:oidcIssuerProfile.enabled,workloadIdentity:securityProfile.workloadIdentity.enabled}"
```

---

## Kubernetes Validation

```bash
kubectl get serviceaccount -A
```

Then:

```bash
kubectl describe serviceaccount <service-account> \
  -n <namespace>
```

---

## Engineering Lesson

Workload Identity is a trust chain.

Troubleshooting should validate each link independently rather than treating it as a single feature toggle.

---

# Issue 10 — Federated Identity Must Match Namespace and ServiceAccount

## Problem

Federated Identity Credentials are sensitive to the exact Kubernetes identity.

The subject normally follows a pattern similar to:

```text
system:serviceaccount:<namespace>:<serviceaccount>
```

A mismatch prevents federation.

---

## Common Failure Pattern

For example:

```text
Federated Credential expects:
system:serviceaccount:applications:app-sa

Pod actually uses:
system:serviceaccount:applications-staging:app-sa
```

These are different identities.

---

## Project Design

Separate federated identity credentials were created for the application environments, including:

* Development;
* Staging;
* Production.

This allows the shared workload managed identity to trust only the explicitly configured Kubernetes identities.

---

## Engineering Lesson

Kubernetes namespaces are part of workload identity.

Moving an application between namespaces changes its identity subject even if the ServiceAccount has the same name.

---

# Issue 11 — Staging and Production Need Their Own Federation

## Problem Domain

After implementing Workload Identity for the initial application environment, Staging and Production also required valid federated identity relationships.

Simply copying the Deployment does not automatically create Azure identity trust for a new namespace.

---

## Required Model

```text
Dev ServiceAccount
      |
      +--> Dev Federated Credential

Staging ServiceAccount
      |
      +--> Staging Federated Credential

Production ServiceAccount
      |
      +--> Production Federated Credential
```

---

## Resolution

Environment-specific federated credentials were managed through Terraform.

This kept identity configuration reproducible instead of creating portal-only configuration.

---

## Engineering Lesson

Environment promotion includes more than application manifests.

Identity, authorization, secrets, networking, and observability must also support the promoted environment.

---

# Issue 12 — Key Vault Access Requires Both Authentication and Authorization

## Problem

Successfully obtaining a workload identity token does not automatically mean the application can retrieve Key Vault secrets.

Two separate questions exist:

```text
Can the workload authenticate?
              |
              v
Workload Identity


Is that identity authorized?
              |
              v
Azure RBAC
```

---

## Required Relationship

```text
Kubernetes Pod
      |
      v
Workload Identity
      |
      v
Managed Identity
      |
      | Key Vault Secrets User
      v
Azure Key Vault
```

---

## Investigation

If authentication succeeds but secret access fails, inspect Azure RBAC:

```bash
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --output table
```

Also validate the Key Vault scope.

---

## Engineering Lesson

Authentication answers:

> Who are you?

Authorization answers:

> What are you allowed to do?

Cloud troubleshooting must distinguish the two.

---

# Issue 13 — SecretProviderClass Must Match the Workload

## Problem Domain

Key Vault CSI integration requires Kubernetes and Azure configuration to agree.

Potential mismatches include:

* wrong Key Vault name;
* wrong tenant;
* wrong managed identity client ID;
* wrong object name;
* wrong ServiceAccount;
* wrong namespace.

---

## Investigation

Check:

```bash
kubectl get secretproviderclass -A
```

Then:

```bash
kubectl describe secretproviderclass <name> \
  -n <namespace>
```

Check the pod:

```bash
kubectl describe pod <pod> -n <namespace>
```

CSI-related mount errors normally appear in pod events.

---

## Engineering Lesson

When a Kubernetes volume mount fails for an external secret provider, `kubectl describe pod` is usually more useful than repeatedly inspecting the Deployment YAML.

Events reveal the runtime failure.

---

# Issue 14 — Kubernetes SecurityContext Hardening Required Application Changes

## Problem

The project introduced stronger Kubernetes workload security controls.

The application workloads needed to operate correctly without unnecessary root privilege.

Security hardening included explicit `securityContext` configuration and non-root execution.

---

## Why This Matters

A container that only works as root has a larger runtime attack surface.

The desired model is:

```text
Application
    |
    v
Non-Root Container
    |
    v
Restricted Runtime Privilege
```

---

## Resolution

Deployment manifests were updated with explicit workload/container security controls.

Validation included ensuring that the application continued to start successfully after hardening.

---

## Important Lesson

Security hardening must be tested.

Adding:

```yaml
runAsNonRoot: true
```

does not automatically mean an arbitrary image will work.

The image itself must support non-root execution.

---

## Engineering Lesson

Security controls should not simply be copied into YAML.

Each control must be compatible with the application and validated at runtime.

---

# Issue 15 — `kubectl apply` Does Not Prove Deployment Success

## Problem

A Kubernetes manifest can be accepted successfully while the resulting application fails.

For example:

```text
kubectl apply
     |
     v
Success

BUT

Pod
 |
 v
CrashLoopBackOff
```

---

## Correct Validation

After deployment:

```bash
kubectl rollout status deployment/<deployment> \
  -n <namespace>
```

Then:

```bash
kubectl get pods -n <namespace>
```

If necessary:

```bash
kubectl describe pod <pod> -n <namespace>
```

and:

```bash
kubectl logs <pod> -n <namespace>
```

---

## Engineering Lesson

Infrastructure declaration success and runtime application health are different validation stages.

A production-quality CD pipeline must validate both.

---

# Issue 16 — CI Filesystem and Image Scanning Solve Different Problems

## Problem Domain

It may initially appear redundant to run both:

```text
Trivy filesystem scan
```

and:

```text
Trivy image scan
```

They actually inspect different security surfaces.

---

## Filesystem Scan

Evaluates repository content and dependencies before the final image exists.

---

## Image Scan

Evaluates the built artifact, including:

* base-image packages;
* OS libraries;
* packages installed during build;
* runtime dependencies.

---

## Engineering Lesson

Security controls should follow the artifact lifecycle.

```text
Source
  |
  +--> Source Security

Build
  |
  +--> Artifact Security

Deploy
  |
  +--> Runtime Security
```

This is defense in depth.

---

# Issue 17 — Security Reports Should Survive the Pipeline Run

## Problem

Security information written only to console logs is difficult to use later.

Pipeline logs are not an ideal security evidence repository.

---

## Resolution

Trivy reports were generated and published as pipeline artifacts in formats including:

```text
JSON
SARIF
```

---

## Benefits

This provides:

* audit evidence;
* downloadable reports;
* later investigation;
* security-tool integration;
* historical comparison.

---

## Engineering Lesson

A mature DevSecOps pipeline should produce evidence, not merely console output.

---

# Issue 18 — Security Gates Must Fail Correctly

## Problem Domain

A vulnerability scanner that always allows the pipeline to continue is informational rather than preventative.

The desired behavior is:

```text
Trivy
 |
 +--> Acceptable findings
 |        |
 |        v
 |     Continue
 |
 +--> Policy violation
          |
          v
      Fail Pipeline
```

---

## Troubleshooting Approach

When configuring a security gate, validate both paths:

```text
Positive Test
Known-clean artifact should pass.

Negative Test
Known-policy-violating artifact should fail.
```

Without negative testing, it is possible to believe a gate works when it never actually blocks anything.

---

## Engineering Lesson

Security controls need functional testing just like application code.

---

# Issue 19 — Reusable Azure DevOps Templates Require Parameter Discipline

## Problem Domain

The project separates pipeline orchestration from reusable implementation templates.

Templates include:

```text
python-validate.yml
trivy-filesystem-scan.yml
docker-build-push.yml
trivy-image-scan.yml
deploy-job.yml
deploy-aks.yml
notation-sign-verify.yml
notation-verify.yml
```

Reusable templates reduce duplication but introduce parameter dependencies.

---

## Common Failure Causes

Template problems commonly result from:

* missing parameter;
* incorrect parameter name;
* incorrect path;
* variable expansion timing;
* compile-time versus runtime expression confusion;
* incorrect indentation.

---

## Investigation

When Azure DevOps rejects YAML before running an agent, investigate pipeline compilation first.

When YAML compiles but a job fails, investigate runtime variables and the agent environment.

---

## Engineering Lesson

Azure DevOps has two important failure classes:

```text
Pipeline Compilation Failure
          |
          v
No agent job runs


Pipeline Runtime Failure
          |
          v
Agent executes job and command fails
```

Distinguishing these immediately reduces troubleshooting time.

---

# Issue 20 — Self-Hosted Agent Must Be Online

## Problem

The project uses an Azure DevOps self-hosted agent running on AWS EC2.

If the EC2 instance is stopped, Azure DevOps cannot execute jobs assigned to that agent pool.

---

## Architecture

```text
Azure DevOps
     |
     v
Agent Pool
     |
     v
AWS EC2 Agent
     |
     v
Pipeline Job
```

---

## Symptoms

A pipeline may remain queued waiting for an available agent.

---

## Investigation

Check:

1. EC2 instance state;
2. agent process;
3. Azure DevOps agent pool;
4. network connectivity;
5. agent registration.

On the agent host, verify the Azure DevOps agent service/process according to its installation method.

---

## Resolution

Start the EC2 instance and ensure the Azure DevOps agent is online before executing pipelines.

---

## Engineering Lesson

The CI/CD control plane and execution plane are separate.

Azure DevOps may be fully operational while no worker is available to execute the job.

---

# Issue 21 — Self-Hosted Agent Tooling Must Match Pipeline Requirements

## Problem Domain

A self-hosted agent provides control over installed tooling, but this also means the platform owner must maintain that tooling.

Required tools include components such as:

* Docker;
* Azure CLI;
* Terraform;
* kubectl;
* Trivy;
* Notation;
* Git.

---

## Investigation

If a pipeline fails with:

```text
command not found
```

check the agent directly:

```bash
terraform version
az version
kubectl version --client
docker --version
trivy --version
notation version
```

---

## Engineering Lesson

With Microsoft-hosted agents, the provider maintains the worker image.

With self-hosted agents, the platform team owns the runtime environment.

Control and responsibility increase together.

---

# Issue 22 — Azure DevOps Authentication and PAT Handling

## Problem Domain

Azure DevOps administration and agent registration may require authentication mechanisms such as Personal Access Tokens.

PATs are sensitive credentials.

They must never be committed into:

* pipeline YAML;
* Git;
* README files;
* screenshots;
* shell history where avoidable.

---

## Safe Handling

Tokens should be:

* scoped narrowly;
* stored securely;
* rotated when appropriate;
* removed when no longer required.

---

## Engineering Lesson

A PAT should be treated like a password.

The fact that it is generated by a DevOps platform does not make it safe to publish.

---

# Issue 23 — Environment Promotion Must Use the Correct Artifact

## Problem Domain

A multi-environment pipeline can accidentally rebuild an image separately for every environment.

This undermines confidence that the production artifact is the same artifact tested earlier.

---

## Preferred Model

```text
Build Once
    |
    v
Image Version X
    |
    +--> Dev
    |
    +--> Staging
    |
    +--> Production
```

---

## Troubleshooting Question

When Dev and Production behave differently, first verify:

> Are they actually running the same image digest/tag?

Check:

```bash
kubectl get deployment <deployment> \
  -n <namespace> \
  -o jsonpath='{.spec.template.spec.containers[*].image}'
```

---

## Engineering Lesson

Artifact identity should be traceable from source commit to production deployment.

---

# Issue 24 — Production Approval Must Be Attached to the Correct Environment

## Problem Domain

Production approval is an Azure DevOps environment governance control.

If the pipeline does not reference the protected Production environment correctly, the approval may not occur where expected.

---

## Desired Flow

```text
Staging
   |
   v
Production Environment
   |
   v
Approval Check
   |
   v
Production Deployment
```

---

## Validation

The final pipeline should visibly pause at the Production boundary until the configured approval is satisfied.

---

## Engineering Lesson

Governance controls must be tested end-to-end.

Creating an approval configuration is not sufficient if the pipeline does not actually traverse that environment boundary.

---

# Issue 25 — Kubernetes Environment Configuration Can Drift

## Problem Domain

Maintaining completely separate copies of Kubernetes manifests for Dev, Staging, and Production creates duplication.

Duplicated configuration tends to drift.

---

## Resolution

The project uses a Kustomize base-and-overlay structure:

```text
kubernetes/
├── base/
│   └── application/
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

---

## Validation

Before deployment:

```bash
kubectl kustomize kubernetes/overlays/dev
```

```bash
kubectl kustomize kubernetes/overlays/staging
```

```bash
kubectl kustomize kubernetes/overlays/prod
```

Review the rendered manifests.

---

## Engineering Lesson

Validate generated configuration before applying it.

Kustomize reduces duplication but does not eliminate the possibility of an incorrect patch or overlay.

---

# Issue 26 — HPA Requires Metrics and Correct Resource Configuration

## Problem Domain

Creating an HPA object does not guarantee autoscaling will operate correctly.

HPA depends on metrics and workload resource configuration.

---

## Investigation

Check:

```bash
kubectl get hpa -A
```

Then:

```bash
kubectl describe hpa <hpa> -n <namespace>
```

Also check:

```bash
kubectl top pods -n <namespace>
```

---

## Potential Problems

HPA issues may originate from:

* unavailable metrics;
* missing CPU requests;
* incorrect target utilization;
* insufficient replicas;
* workload instability.

---

## Engineering Lesson

Autoscaling is a feedback loop.

Every part must work:

```text
Metrics
  |
  v
HPA Decision
  |
  v
Replica Change
  |
  v
Scheduler
  |
  v
Node Capacity
```

---

# Issue 27 — HPA and Cluster Autoscaler Are Different

## Problem Domain

It is easy to confuse application scaling and infrastructure scaling.

HPA does not create worker nodes.

Cluster Autoscaler does not decide how many application replicas should exist.

---

## Correct Relationship

```text
Load
 |
 v
HPA
 |
 v
More Pods
 |
 v
Insufficient Node Capacity
 |
 v
Cluster Autoscaler
 |
 v
More Nodes
```

---

## Engineering Lesson

Troubleshooting scaling requires identifying whether the bottleneck is:

```text
Application Replica Capacity
```

or:

```text
Cluster Node Capacity
```

The corrective action differs.

---

# Issue 28 — Azure Monitoring Resources Can Exist Without Producing Useful Data

## Problem Domain

Creating:

* Log Analytics;
* DCR;
* diagnostic settings;
* alert rules;

does not automatically prove that useful telemetry is flowing.

---

## Required Validation

The monitoring chain must be tested:

```text
AKS
 |
 v
Telemetry Collection
 |
 v
Log Analytics
 |
 v
KQL Query
 |
 v
Alert Evaluation
```

---

## Investigation

Use Log Analytics to confirm data is actually arriving.

Then confirm that the scheduled query evaluates the intended condition.

---

## Engineering Lesson

Provisioning observability resources is not the same as validating observability.

Monitoring requires end-to-end signal testing.

---

# Issue 29 — DCR Creation and DCR Association Are Different

## Problem Domain

A Data Collection Rule may exist without being associated with AKS.

The relationship is:

```text
DCR
 +
AKS
 |
 v
DCR Association
```

---

## Engineering Lesson

When telemetry is missing, do not merely verify that the configuration object exists.

Verify that it is attached to the resource producing telemetry.

---

# Issue 30 — Alerting Requires a Real Signal Path

## Problem Domain

An Azure Monitor alert rule can be successfully provisioned but never trigger if:

* telemetry is missing;
* KQL query is incorrect;
* threshold is inappropriate;
* evaluation window is incorrect;
* Action Group is not connected as intended.

---

## Validation Strategy

Use a controlled non-production failure.

For example:

```text
Introduce Temporary Unhealthy Workload
              |
              v
Confirm Telemetry
              |
              v
Confirm Query Result
              |
              v
Confirm Alert
              |
              v
Restore Workload
```

---

## Engineering Lesson

Alerting should be tested with controlled failure injection rather than assumed to work because Terraform completed successfully.

---

# Issue 31 — Notation Trust Certificate Versus Private Key

## Situation

The repository contains:

```text
.pipeline/truststore/x509/ca/aedp/aedp-container-signing.pem
```

Because `.pem` files can contain either certificates or private keys, this required validation before accepting it in the public repository.

---

## Validation

The certificate was inspected with:

```bash
openssl x509 \
  -in .pipeline/truststore/x509/ca/aedp/aedp-container-signing.pem \
  -noout \
  -subject \
  -issuer \
  -serial \
  -dates
```

The file begins with:

```text
-----BEGIN CERTIFICATE-----
```

rather than:

```text
-----BEGIN PRIVATE KEY-----
```

or:

```text
-----BEGIN RSA PRIVATE KEY-----
```

The certificate identifies the project container-signing trust identity and is self-signed.

---

## Private Key Check

The repository was additionally checked with:

```bash
git grep -n -E \
'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|BEGIN PRIVATE KEY'
```

The expected result was no tracked private key.

---

## Resolution

The public X.509 trust certificate can remain tracked.

The private signing key must remain outside the public repository.

---

## Engineering Lesson

File extensions are not enough to classify security-sensitive files.

A `.pem` file must be inspected to determine whether it contains:

```text
Public Certificate
```

or:

```text
Private Key
```

Never assume based solely on the extension.

---

# Issue 32 — `.gitignore` Does Not Remove Already Tracked Files

## Important Git Behavior

Adding:

```text
*.pem
```

or:

```text
*.tfstate
```

to `.gitignore` does not automatically remove a file that Git already tracks.

---

## Validation

Check:

```bash
git ls-files
```

or:

```bash
git ls-files | grep <filename>
```

---

## If a Sensitive File Was Already Tracked

Simply adding it to `.gitignore` is insufficient.

The file must be removed from the Git index:

```bash
git rm --cached <file>
```

If sensitive material was previously committed, repository history may also require remediation and the credential must be rotated.

---

## Engineering Lesson

`.gitignore` prevents new untracked files from being added.

It is not a security cleanup mechanism for existing Git history.

---

# Issue 33 — Public Portfolio Screenshots Can Leak Sensitive Information

## Problem Domain

Azure Portal and Azure DevOps screenshots can expose:

* subscription IDs;
* tenant IDs;
* email addresses;
* PATs;
* secret values;
* client IDs;
* public IP addresses;
* pipeline variables;
* internal resource identifiers.

---

## Screenshot Review Process

Before committing an image:

```text
Capture
   |
   v
Inspect
   |
   v
Crop / Redact
   |
   v
Inspect Again
   |
   v
Commit
```

---

## Never Publish

Do not publish screenshots containing:

* secret values;
* private keys;
* PATs;
* passwords;
* service-principal client secrets;
* authentication tokens.

---

## Engineering Lesson

Documentation itself is part of the attack surface.

A secure platform can still leak credentials through careless screenshots.

---

# Issue 34 — Architecture Documentation Can Drift From Implementation

## Problem

Architecture diagrams and README descriptions can become inaccurate as infrastructure evolves.

For example, documentation might accidentally imply:

```text
Dev AKS
Staging AKS
Production AKS
```

when the portfolio implementation actually uses:

```text
One AKS Cluster
     |
     +--> Dev
     +--> Staging
     +--> Production
```

---

## Resolution

The architecture documentation explicitly distinguishes:

* the implemented cost-conscious portfolio topology;
* potential stronger enterprise isolation patterns.

---

## Engineering Lesson

Documentation should describe what exists first.

Future-state or enterprise alternatives should be clearly labelled as improvements rather than presented as already implemented.

---

# Issue 35 — Mermaid CLI Required a Headless Browser

## Problem

The architecture diagram was maintained as Mermaid source:

```text
diagrams/azure-enterprise-devops-platform.mmd
```

Mermaid CLI was installed successfully:

```bash
sudo npm install -g @mermaid-js/mermaid-cli
```

but initial rendering failed with an error indicating that `chrome-headless-shell` could not be found.

---

## Root Cause

Mermaid CLI uses Puppeteer for browser-based rendering.

The CLI existed, but the required headless browser binary had not yet been installed in Puppeteer's cache.

---

## Resolution

The required browser was installed with:

```bash
npx puppeteer browsers install chrome-headless-shell
```

The browser became available under:

```text
~/.cache/puppeteer/
```

The architecture diagram could then be rendered successfully:

```bash
mmdc \
  -i diagrams/azure-enterprise-devops-platform.mmd \
  -o docs/images/architecture/azure-enterprise-devops-platform.svg \
  -b transparent
```

---

## Result

The generated SVG was stored under:

```text
docs/images/architecture/azure-enterprise-devops-platform.svg
```

The Mermaid source remains under:

```text
diagrams/azure-enterprise-devops-platform.mmd
```

---

## Engineering Lesson

A CLI being installed does not mean all of its runtime dependencies are available.

When a tool fails after installation, distinguish between:

```text
Executable Missing
```

and:

```text
Runtime Dependency Missing
```

before reinstalling the entire tool.

---

# Issue 36 — Incorrect Puppeteer Browser Path

## Problem

After the successful Puppeteer-managed browser installation, an additional local configuration attempted to use:

```text
/usr/bin/chromium
```

However, Chromium was not installed at that path.

Mermaid therefore reported that the configured browser could not be found.

---

## Root Cause

The manually configured browser path overrode the already functioning Puppeteer-managed browser discovery.

---

## Resolution

The unnecessary configuration file was removed.

The working configuration was allowed to use Puppeteer's installed `chrome-headless-shell`.

---

## Engineering Lesson

Once a tool works, avoid adding unnecessary configuration.

Explicit configuration can override valid automatic discovery and create a new failure.

---

# Issue 37 — Azure Resources Are Ephemeral but Documentation Is Persistent

## Operating Model

The portfolio platform does not need to remain online continuously.

AKS and other Azure resources create ongoing cost.

The AWS EC2 self-hosted agent also does not need to run continuously.

---

## Cost-Control Strategy

```text
Need Platform
    |
    v
terraform apply
    |
    v
Start EC2 Agent
    |
    v
Run / Validate / Demonstrate
    |
    v
Capture Evidence
    |
    v
terraform destroy
    |
    v
Stop EC2 Agent
```

---

## Important Distinction

The platform can be ephemeral because the implementation remains persistent in:

* Terraform;
* Kubernetes manifests;
* Azure DevOps YAML;
* documentation;
* architecture diagrams;
* Git history.

---

## Engineering Lesson

Infrastructure as Code changes the value proposition of infrastructure.

The valuable asset is not the manually configured cloud environment.

The valuable asset is the reproducible system definition.

---

# Troubleshooting Terraform

When Terraform fails, use the following sequence.

## Step 1 — Confirm Directory

```bash
pwd
```

## Step 2 — Format

```bash
terraform fmt -check -recursive
```

## Step 3 — Validate

```bash
terraform validate
```

## Step 4 — Initialize

```bash
terraform init
```

If backend configuration changed:

```bash
terraform init -reconfigure
```

## Step 5 — Inspect State

```bash
terraform state list
```

## Step 6 — Plan

```bash
terraform plan
```

Do not proceed to `apply` until the plan is understood.

---

# Troubleshooting Azure Authentication

Check the active account:

```bash
az account show
```

List subscriptions:

```bash
az account list --output table
```

Select the intended subscription when required:

```bash
az account set --subscription <subscription>
```

Before modifying infrastructure, confirm that the intended Azure subscription is active.

---

# Troubleshooting AKS Access

Retrieve credentials:

```bash
az aks get-credentials \
  --resource-group <resource-group> \
  --name <aks-name> \
  --overwrite-existing
```

Validate:

```bash
kubectl cluster-info
```

Then:

```bash
kubectl get nodes
```

If these fail, troubleshoot cluster authentication before troubleshooting application workloads.

---

# Troubleshooting Kubernetes Pods

Start with:

```bash
kubectl get pods -A
```

For a failing pod:

```bash
kubectl describe pod <pod> -n <namespace>
```

Then:

```bash
kubectl logs <pod> -n <namespace>
```

For multi-container pods:

```bash
kubectl logs <pod> \
  -n <namespace> \
  -c <container>
```

---

# Common Kubernetes Pod States

## Pending

Investigate:

* scheduling;
* resources;
* node capacity;
* taints;
* PVCs;
* affinity.

## ImagePullBackOff

Investigate:

* image name;
* image tag;
* ACR;
* AcrPull RBAC;
* registry connectivity.

## CrashLoopBackOff

Investigate:

* application logs;
* command/entrypoint;
* environment configuration;
* secrets;
* securityContext;
* application dependencies.

## CreateContainerConfigError

Investigate:

* ConfigMaps;
* Secrets;
* ServiceAccounts;
* volume references.

---

# Troubleshooting Workload Identity

Use a layered approach.

## Layer 1 — AKS

Confirm OIDC and Workload Identity.

## Layer 2 — ServiceAccount

```bash
kubectl get serviceaccount <name> \
  -n <namespace> \
  -o yaml
```

## Layer 3 — Pod

Verify the pod uses the intended ServiceAccount:

```bash
kubectl get pod <pod> \
  -n <namespace> \
  -o jsonpath='{.spec.serviceAccountName}'
```

## Layer 4 — Federated Credential

Confirm:

* issuer;
* subject;
* audience;
* managed identity.

## Layer 5 — Azure RBAC

Confirm the managed identity has permission to the target Azure resource.

---

# Troubleshooting Key Vault

If Key Vault access fails, determine whether the problem is:

```text
Authentication
```

or:

```text
Authorization
```

Then check CSI integration.

Useful Kubernetes commands:

```bash
kubectl get secretproviderclass -A
```

```bash
kubectl describe pod <pod> -n <namespace>
```

Look for volume-mount and identity errors in Events.

---

# Troubleshooting ACR

Verify repository content:

```bash
az acr repository list \
  --name <acr-name> \
  --output table
```

List tags:

```bash
az acr repository show-tags \
  --name <acr-name> \
  --repository <repository> \
  --output table
```

Then compare the image with the Kubernetes Deployment.

---

# Troubleshooting Azure DevOps CI

When CI fails, identify the stage:

```text
Validation
Filesystem Scan
Docker Build
Image Scan
Artifact Publication
ACR Push
```

Do not treat the entire CI pipeline as one troubleshooting unit.

Find the first failed job and investigate there.

---

# Troubleshooting Azure DevOps CD

For CD:

```text
Pipeline
   |
   v
Agent
   |
   v
Azure Authentication
   |
   v
AKS Authentication
   |
   v
Kustomize
   |
   v
kubectl
   |
   v
Rollout
```

Determine which boundary failed.

If `kubectl apply` succeeds but rollout fails, move the investigation into Kubernetes.

---

# Troubleshooting the Self-Hosted Agent

Check whether the AWS EC2 instance is running.

Then verify the agent is online in Azure DevOps.

Validate required tools:

```bash
az version
terraform version
docker --version
kubectl version --client
trivy --version
```

A pipeline queued indefinitely often indicates execution-capacity problems rather than YAML problems.

---

# Troubleshooting Monitoring

Use this order:

```text
Is AKS healthy?
      |
      v
Is telemetry being collected?
      |
      v
Is data reaching Log Analytics?
      |
      v
Does the KQL query return expected data?
      |
      v
Does the alert evaluate?
      |
      v
Does the Action Group execute?
```

This isolates collection, storage, detection, and notification.

---

# Troubleshooting HPA

Check:

```bash
kubectl get hpa -A
```

Then:

```bash
kubectl describe hpa <name> -n <namespace>
```

Check workload resource configuration and metrics.

Do not assume that a replica-count problem is automatically an HPA problem.

---

# Safe Repository Validation

Before publishing the repository, run:

```bash
git status
```

Then:

```bash
git ls-files | grep -E \
'(\.tfstate|\.tfstate\.backup|\.tfvars$|tfplan$|\.key$|\.pfx$|\.p12$|\.kubeconfig$)'
```

Inspect any returned files.

Check for private keys:

```bash
git grep -n -E \
'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|BEGIN PRIVATE KEY'
```

Expected result:

```text
no output
```

---

# Pre-Destroy Checklist

Before destroying the Azure environment:

```text
[ ] Required screenshots captured
[ ] CI evidence captured
[ ] CD evidence captured
[ ] ACR evidence captured
[ ] AKS evidence captured
[ ] Workload Identity evidence captured
[ ] Key Vault evidence captured
[ ] Monitoring evidence captured
[ ] Security evidence captured
[ ] Terraform outputs reviewed
[ ] No additional validation required
```

Then:

```bash
cd terraform/environments/dev
terraform plan -destroy
```

Review carefully.

Then:

```bash
terraform destroy
```

---

# Post-Destroy Validation

After Terraform completes:

```bash
terraform state list
```

The workload environment state should reflect the completed destruction as expected.

Azure can also be checked for remaining resources.

The Terraform backend should remain if it is intentionally managed by the separate bootstrap layer.

---

# Final Screenshot Session Troubleshooting Strategy

During the final evidence session, avoid making unnecessary architecture changes.

The objective is:

```text
Recreate Known-Good Platform
          |
          v
Validate
          |
          v
Run Known-Good Pipelines
          |
          v
Capture Evidence
```

If something fails, compare the recreated environment with the last known-good configuration before introducing new features.

The screenshot session is validation, not another redesign phase.

---

# Root-Cause Analysis Template

For future incidents, use the following structure.

## Symptom

What was observed?

## Impact

What stopped working?

## Failure Domain

Which system or boundary failed?

## Evidence

What commands, logs, events, or pipeline output demonstrated the problem?

## Root Cause

Why did the failure occur?

## Resolution

What change corrected it?

## Validation

How was the fix proven?

## Prevention

What prevents recurrence?

## Engineering Lesson

What reusable knowledge came from the incident?

This structure converts troubleshooting history into engineering knowledge.

---

# Key Troubleshooting Lessons

Several lessons from the project are broadly applicable.

## 1. Start at the First Failure

Later errors are frequently consequences of an earlier failure.

Find the first meaningful error.

---

## 2. Separate Authentication From Authorization

Successful identity federation does not imply resource permission.

Always ask:

```text
Can I authenticate?
```

and separately:

```text
Am I authorized?
```

---

## 3. Kubernetes Events Are Critical Evidence

For workload failures:

```bash
kubectl describe pod
```

often provides more useful information than repeatedly reading YAML.

---

## 4. Infrastructure Creation Does Not Prove Integration

A resource existing in Azure does not prove another resource can use it.

Examples:

```text
ACR exists
!=
AKS can pull from ACR
```

```text
Key Vault exists
!=
Pod can access Key Vault
```

```text
DCR exists
!=
AKS telemetry is flowing
```

Integration must be validated.

---

## 5. Security Controls Must Be Tested

A configured security gate is not necessarily an effective security gate.

Test successful and failing paths.

---

## 6. CI/CD Agents Are Infrastructure

The self-hosted agent requires:

* lifecycle management;
* patching;
* security;
* tooling;
* capacity;
* connectivity.

Treat it like production infrastructure.

---

## 7. Avoid Broad Permissions as a Troubleshooting Shortcut

Granting Owner or Contributor at subscription scope may make an authorization error disappear, but it hides the real permission requirement.

Determine the exact required role and scope.

---

## 8. Do Not Fix IaC Problems Manually in the Portal Unless Diagnosing

A manual portal change may temporarily fix a problem while creating Terraform drift.

The preferred pattern is:

```text
Diagnose
   |
   v
Change Terraform
   |
   v
Plan
   |
   v
Apply
   |
   v
Validate
```

---

## 9. Reproducibility Is a Troubleshooting Tool

Destroying and recreating the environment verifies whether the platform depends on undocumented manual state.

A reproducible rebuild is strong evidence that the Infrastructure as Code implementation is complete.

---

## 10. Documentation Is Part of Reliability

Troubleshooting knowledge that exists only in one engineer's memory will eventually be lost.

Documenting:

* symptom;
* cause;
* fix;
* validation;
* lesson;

turns an incident into reusable operational knowledge.

---

# Final Troubleshooting Model

The most important troubleshooting principle from the project is to reason through dependencies.

```text
Source
  |
  v
CI
  |
  v
Artifact
  |
  v
Registry
  |
  v
CD
  |
  v
AKS
  |
  v
Kubernetes
  |
  v
Identity
  |
  v
Secrets
  |
  v
Application
  |
  v
Monitoring
```

When a failure appears at one layer, investigate both that layer and the dependency immediately below it.

The objective is not trial-and-error configuration.

The objective is evidence-driven root-cause analysis.

