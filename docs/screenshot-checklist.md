# Final Evidence Screenshot Checklist

Use this checklist during the final Azure Enterprise DevOps Platform validation session.

Before capturing any screenshot:

* [ ] Check for passwords, tokens, PATs, private keys, and secret values.
* [ ] Hide or crop unnecessary subscription and tenant identifiers.
* [ ] Hide personal email addresses where unnecessary.
* [ ] Use descriptive filenames exactly as listed below.
* [ ] Prefer evidence of working capability over static resource existence.

---

# Terraform

* [ ] `docs/images/terraform/terraform-apply-success.png`

  * Capture the final successful `terraform apply`.
  * Ideally show the apply summary and important outputs.
  * This final apply should occur after the previous complete environment destruction, demonstrating reproducibility.

---

# Azure Networking

* [ ] `docs/images/azure/vnet-subnets.png`

  * Azure Portal → Virtual Network → Subnets.
  * Show the AKS subnet and private-endpoint subnet.
  * Do not expose unnecessary subscription information.

---

# AKS

* [ ] `docs/images/aks/aks-cluster-overview.png`

  * Azure Portal → AKS → Overview.
  * Show cluster status and region.

* [ ] `docs/images/aks/aks-node-pools.png`

  * Azure Portal → AKS → Node pools.
  * Show system and user node pools.
  * Include autoscaling settings if visible.

* [ ] `docs/images/aks/aks-workloads.png`

  * Run:

```bash
kubectl get pods -A -o wide
```

* Ensure Dev, Staging, and Production workloads are healthy.

* [ ] `docs/images/aks/hpa.png`

  * Run:

```bash
kubectl get hpa -A
```

* Show HPA resources and target/current values.

---

# Azure Container Registry

* [ ] `docs/images/azure/acr-images.png`

  * Azure Portal → ACR → Repositories.
  * Open the application repository.
  * Show meaningful image tags.

---

# Workload Identity

* [ ] `docs/images/security/workload-identity-federation.png`

  * Azure Portal → Managed Identity → Federated credentials.
  * Show Dev, Staging, and Production federated credentials.
  * Avoid exposing unnecessary IDs.

---

# Azure Key Vault

* [ ] `docs/images/security/key-vault-overview.png`

  * Azure Portal → Key Vault.
  * Show the vault or secret inventory.
  * Never display actual secret values.

* [ ] `docs/images/security/key-vault-csi.png`

  * Use terminal evidence such as:

```bash
kubectl get secretproviderclass -A
```

* Optionally combine with healthy application pod evidence proving the CSI integration works.

---

# Kubernetes Security

* [ ] `docs/images/security/kubernetes-security-context.png`

  * Show the deployed workload SecurityContext.

Suggested command:

```bash
kubectl get deployment -A -o yaml | \
  grep -A20 -B5 -E 'securityContext|runAsNonRoot|allowPrivilegeEscalation'
```

* Ensure output clearly demonstrates non-root/hardened execution.

---

# Terraform Backend Security

* [ ] `docs/images/security/terraform-backend-networking.png`

  * Azure Portal → Terraform backend storage account → Networking.
  * Show default network deny/restricted access configuration.
  * Hide unnecessary IP/account information.

---

# CI Pipeline

* [ ] `docs/images/pipelines/ci-pipeline-success.png`

  * Azure DevOps → Pipelines → final successful CI run.
  * Show the relevant stages/jobs.

* [ ] `docs/images/security/trivy-filesystem-scan.png`

  * Open the successful filesystem scan job.
  * Show the clean scan/security gate.

* [ ] `docs/images/security/trivy-image-scan.png`

  * Open the successful image scan job.
  * Show the final image was scanned successfully.

* [ ] `docs/images/security/security-report-artifacts.png`

  * Azure DevOps → successful CI run → Published artifacts.
  * Show JSON and SARIF reports.

---

# CD Pipeline

* [ ] `docs/images/pipelines/cd-dev-success.png`

  * Show successful Development deployment.

* [ ] `docs/images/pipelines/cd-staging-success.png`

  * Show successful Staging deployment.

* [ ] `docs/images/pipelines/cd-production-approval.png`

  * Capture the Production approval/check boundary.

* [ ] `docs/images/pipelines/cd-prod-success.png`

  * Show the complete Dev → Staging → Production pipeline successful.

---

# Azure Monitoring

* [ ] `docs/images/monitoring/container-insights.png`

  * Azure Portal → AKS → Insights.
  * Show active node/workload telemetry.

* [ ] `docs/images/monitoring/log-analytics-query.png`

  * Log Analytics → run a useful AKS query.
  * Capture returned telemetry rather than an empty query editor.

* [ ] `docs/images/monitoring/application-alert-rule.png`

  * Azure Monitor → Alerts → Alert rules.
  * Show the unhealthy-application-pods scheduled query alert.

* [ ] `docs/images/monitoring/action-group.png`

  * Azure Monitor → Action Groups.
  * Show the platform Action Group.
  * Hide notification email addresses where appropriate.

---

# Final Validation Before Destroy

* [ ] CI pipeline successful.
* [ ] Dev deployment successful.
* [ ] Staging deployment successful.
* [ ] Production approval demonstrated.
* [ ] Production deployment successful.
* [ ] Dev workloads healthy.
* [ ] Staging workloads healthy.
* [ ] Production workloads healthy.
* [ ] Workload Identity functioning.
* [ ] Key Vault integration functioning.
* [ ] HPA exists and reports metrics.
* [ ] Container Insights contains telemetry.
* [ ] Log Analytics query returns AKS data.
* [ ] Alert rule exists and is enabled.
* [ ] Required screenshots captured.
* [ ] Screenshots reviewed for secrets.

---

# Cleanup

After all evidence has been captured:

```bash
cd terraform/environments/dev
terraform plan -destroy
terraform destroy
```

Then stop the AWS EC2 self-hosted Azure DevOps agent.

The final Azure deployment should be used for validation and evidence collection, not additional architecture redesign.

