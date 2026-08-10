# Enterprise Azure DevOps CI/CD & AKS Platform

Production-oriented Azure DevOps platform demonstrating Infrastructure as Code, CI/CD automation, containerized workloads, AKS, ACR, Key Vault integration, workload identity, security controls, observability, autoscaling, multi-environment deployments, and controlled production releases.

## Project Goals

This project demonstrates how an engineering organization can build a repeatable Azure platform for deploying containerized applications using:

- Microsoft Azure
- Terraform
- Azure DevOps YAML Pipelines
- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR)
- Azure Key Vault
- Microsoft Entra Workload Identity
- Kubernetes
- CI/CD security controls
- Horizontal Pod Autoscaling
- Azure Monitor and Log Analytics
- Dev, staging, and production environments
- Production deployment approvals

## Architecture

Architecture documentation will be maintained under:

```text
docs/architecture.md
Repository Structure
application/      Application source and Docker assets
terraform/        Azure infrastructure as code
kubernetes/       Kubernetes manifests and environment overlays
pipelines/        Azure DevOps CI/CD pipeline definitions
security/         Security configuration and validation
monitoring/       Monitoring configuration
scripts/          Operational automation
docs/             Architecture and engineering documentation
diagrams/         Architecture diagrams
Status

Project implementation in progress.
