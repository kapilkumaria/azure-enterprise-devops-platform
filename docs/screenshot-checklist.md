# Final Evidence Screenshot Checklist

Use this checklist during the final Azure Enterprise DevOps Platform validation and evidence-collection session.

The objective is to capture concise evidence that demonstrates implemented platform capabilities rather than collecting screenshots of every Azure resource.

Before capturing any screenshot:

* [x] Check for passwords, tokens, PATs, private keys, secret values, and other credentials.
* [x] Hide or crop unnecessary subscription IDs, tenant IDs, client IDs, object IDs, and resource identifiers.
* [x] Hide personal email addresses where they are not required as evidence.
* [x] Hide administrator public IP addresses where they are not required.
* [x] Review terminal history and command output for sensitive values before capturing.
* [x] Use descriptive filenames exactly as listed below.
* [x] Prefer evidence of working capability over static resource existence.
* [x] Capture only evidence that corresponds to functionality implemented by this repository.

---

# Terraform

* [x] `docs/images/terraform/terraform-apply-success.png`

  * Capture the final successful `terraform apply`.
  * Show the apply summary and useful non-sensitive outputs.
  * The final apply should occur after a previous complete Development environment destruction so the screenshot supports Infrastructure as Code reproducibility.
  * Do not expose sensitive Terraform output values.

---

# Azure Networking

* [x] `docs/images/azure/vnet-subnets.png`

  * Azure Portal → Virtual Network → Subnets.
  * Show the AKS subnet and private-endpoint subnet.
  * Ensure the resource names are readable.
  * Do not expose unnecessary subscription information.

---

# AKS

* [x] `docs/images/aks/aks-cluster-overview.png`

  * Azure Portal → AKS → Overview.
  * Show the cluster in a healthy/running state.
  * Include the Azure region and cluster name where useful.

* [x] `docs/images/aks/aks-node-pools.png`

  * Azure Portal → AKS → Node pools.
  * Show the system and user node pools.
  * Include autoscaling configuration where visible.

* [x] `docs/images/aks/aks-workloads.png`

  * Capture terminal evidence using:

```bash
kubectl get pods -A -o wide
```

  * Ensure Development, Staging, and Production application workloads are healthy.
  * Avoid unnecessary terminal history in the screenshot.

* [x] `docs/images/aks/hpa.png`

  * Capture:

```bash
kubectl get hpa -A
```

  * Show the application HPA resources.
  * Ensure current/target metric values are visible where available.

---

# Azure Container Registry

* [x] `docs/images/azure/acr-images.png`

  * Azure Portal → ACR → Repositories.
  * Open the application repository.
  * Show the image artifact created by the final successful CI run.
  * Prefer evidence that allows the image to be correlated with the final pipeline run.

---

# Workload Identity

* [x] `docs/images/security/workload-identity-federation.png`

  * Azure Portal → Managed Identity → Federated credentials.
  * Show the Development, Staging, and Production federated credentials.
  * Ensure the environment-specific federation model is understandable.
  * Avoid exposing unnecessary tenant, client, principal, or subscription identifiers.

---

# Azure Key Vault

* [x] `docs/images/security/key-vault-overview.png`

  * Azure Portal → Key Vault.
  * Show the vault or secret inventory.
  * Demonstrate that the required secret object exists.
  * Never open or display the actual secret value.

* [x] `docs/images/security/key-vault-csi.png`

  * Capture Kubernetes-side integration evidence such as:

```bash
kubectl get secretproviderclass -A
```

  * Prefer showing the environment, resource name, and healthy application state where practical.
  * Never print the secret value merely to prove that integration works.

---

# Kubernetes Runtime Security

* [x] `docs/images/security/kubernetes-security-context.png`

  * Show the deployed workload runtime-security configuration.

  * Prefer a targeted command such as:

```bash
kubectl get deployment <deployment> \
  -n <namespace> \
  -o yaml | \
  grep -A25 -B5 -E \
  'securityContext|runAsNonRoot|runAsUser|runAsGroup|fsGroup|seccompProfile|privileged|allowPrivilegeEscalation|readOnlyRootFilesystem|capabilities'
```

  * Capture enough output to demonstrate the implemented controls, including where visible:

```text
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile: RuntimeDefault
privileged: false
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities.drop: ALL
```

  * Ensure the screenshot represents the deployed workload rather than only the source YAML.

---

# Terraform Backend Security

* [x] `docs/images/security/terraform-backend-networking.png`

  * Azure Portal → Terraform backend storage account → Networking.
  * Show the restricted storage-account networking configuration.
  * Demonstrate the default-deny network posture and explicitly authorized access model.
  * Hide administrator public IP addresses and unnecessary account identifiers.

---

# CI Pipeline

* [x] `docs/images/pipelines/ci-pipeline-success.png`

  * Azure DevOps → Pipelines → final successful CI run.
  * Show the relevant successful stages/jobs.
  * Prefer a view that makes the overall CI security and artifact workflow understandable.

* [x] `docs/images/security/trivy-filesystem-scan.png`

  * Open the successful Trivy filesystem-security job.
  * Show that the filesystem scan and enforcement gate completed successfully.
  * Prefer output that demonstrates the configured security gate rather than only the job name.

* [x] `docs/images/security/trivy-image-scan.png`

  * Open the successful Trivy container-image scan job.
  * Show that the final deployable image was scanned successfully.
  * Prefer output that can be correlated with the image produced by the CI run.

* [x] `docs/images/security/security-report-artifacts.png`

  * Azure DevOps → successful CI run → Published artifacts.
  * Show the retained machine-readable security evidence.
  * Include the JSON and SARIF reports.

---

# Software Supply Chain

* [x] `docs/images/security/sbom-artifact.png`

  * Azure DevOps → final successful CI run → Published artifacts.
  * Show the generated CycloneDX SBOM.
  * Prefer a view where the SBOM artifact/file name is clearly readable.
  * Do not attempt to display the entire SBOM.

* [x] `docs/images/security/immutable-image-digest.png`

  * Capture CI evidence showing resolution of the pushed ACR image to its immutable OCI digest.
  * The evidence should clearly show that the artifact is identified using:

```text
sha256:<digest>
```

  * It is acceptable to show a shortened surrounding pipeline log as long as the artifact identity is clear.

* [x] `docs/images/security/notation-signing.png`

  * Capture the successful Notation signing step from the final CI run.
  * Demonstrate that the immutable container artifact was signed.
  * Do not expose signing credentials, tokens, or private-key material.

* [x] `docs/images/security/notation-verification.png`

  * Capture successful Notation signature verification.
  * Prefer evidence showing that verification was performed against the signed immutable artifact.
  * If both CI and CD perform verification, prioritize the evidence that most clearly demonstrates the deployment trust gate.

---

# CD Pipeline

* [x] `docs/images/pipelines/cd-dev-success.png`

  * Show successful Development deployment.
  * Include rollout/deployment validation where visible.

* [x] `docs/images/pipelines/cd-staging-success.png`

  * Show successful Staging promotion and deployment.
  * The evidence should support promotion of the validated artifact rather than an independent rebuild.

* [x] `docs/images/pipelines/cd-production-approval.png`

  * Capture the Azure DevOps Production approval/check boundary.
  * Prefer the pipeline waiting at the Production governance boundary before approval.
  * Hide approver email addresses if they are unnecessary.

* [x] `docs/images/pipelines/cd-prod-success.png`

  * Show the complete successful promotion path:

```text
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

  * Prefer a pipeline summary where all relevant deployment stages are visibly successful.

---

# Azure Monitoring

* [x] `docs/images/monitoring/container-insights.png`

  * Azure Portal → AKS → Insights.
  * Show active Kubernetes node or workload telemetry.
  * Capture actual telemetry rather than only the Container Insights navigation page.

* [x] `docs/images/monitoring/log-analytics-query.png`

  * Log Analytics → execute a useful AKS-related KQL query.
  * Capture returned telemetry.
  * Do not use an empty query editor as evidence.

* [x] `docs/images/monitoring/application-alert-rule.png`

  * Azure Monitor → Alerts → Alert rules.
  * Show the implemented unhealthy-application-pods scheduled query alert.
  * Ensure the rule name and enabled state are visible where practical.

* [x] `docs/images/monitoring/action-group.png`

  * Azure Monitor → Action Groups.
  * Show the platform Action Group.
  * Hide notification email addresses or other personal contact information where appropriate.

---

# Final Validation Before Teardown

## Infrastructure

* [x] Terraform recreation completed successfully.
* [x] AKS cluster is healthy.
* [x] System and user node pools are healthy.
* [x] Required Azure RBAC assignments are functioning.

## Application Environments

* [x] Development workloads are healthy.
* [x] Staging workloads are healthy.
* [x] Production workloads are healthy.
* [x] HPA resources exist and report metrics.
* [x] AKS Cluster Autoscaler configuration is present and healthy.

## Identity and Secrets

* [x] Workload Identity federation is functioning.
* [x] Development federation is present.
* [x] Staging federation is present.
* [x] Production federation is present.
* [x] Key Vault integration is functioning.
* [x] SecretProviderClass resources are present.
* [x] No secret values were exposed during validation.

## CI and Software Supply Chain

* [x] CI pipeline is successful.
* [x] Trivy filesystem security gate passed.
* [x] Trivy image security gate passed.
* [x] JSON security evidence was generated.
* [x] SARIF security evidence was generated.
* [x] CycloneDX SBOM was generated.
* [x] Container image was pushed to ACR.
* [x] Immutable image digest was resolved.
* [x] Artifact signing succeeded.
* [x] Signature verification succeeded.

## CD and Governance

* [x] Development deployment succeeded.
* [x] Staging deployment succeeded.
* [x] Production approval boundary was demonstrated.
* [x] Production deployment succeeded.
* [x] The validated artifact was promoted through the deployment lifecycle.

## Runtime Security

* [x] Application runs as non-root.
* [x] Privileged execution is disabled.
* [x] Privilege escalation is disabled.
* [x] Root filesystem is read-only.
* [x] Linux capabilities are dropped.
* [x] RuntimeDefault seccomp profile is configured.

## Observability

* [x] Container Insights contains telemetry.
* [x] Log Analytics query returns AKS data.
* [x] Data Collection Rule and association are configured.
* [x] AKS diagnostic settings are configured.
* [x] Scheduled query alert exists and is enabled.
* [x] Action Group response path is configured.

## Evidence Review

* [x] Every required screenshot has been captured.
* [x] Screenshot filenames match the documentation references.
* [x] Screenshots were reviewed for credentials and sensitive information.
* [x] No passwords, tokens, PATs, private keys, or secret values are visible.
* [x] Unnecessary personal information has been cropped or redacted.
* [x] Screenshots demonstrate implemented capabilities rather than unimplemented future-state features.

---

# Cleanup

Only begin cleanup after all final validation and evidence collection are complete.

First review the destroy scope:

```bash
cd terraform/environments/dev

terraform plan -destroy
```

Confirm that the plan targets the intended Development workload environment and does not include the separately managed Terraform backend.

Then destroy the workload environment:

```bash
terraform destroy
```

After destruction:

```bash
terraform state list
```

Confirm that the workload environment has been removed as expected.

The separately managed Terraform backend should remain available if it is intentionally retained by the bootstrap layer.

Finally, stop the AWS EC2 self-hosted Azure DevOps agent when it is no longer required.

The final Azure deployment should be used for reproducibility validation, end-to-end pipeline validation, security and observability verification, and evidence collection rather than additional architecture redesign.