# Terraform Infrastructure (Multi-Cloud Ready)

Clean, modular Terraform layout supporting **GCP** (active), **AWS**, and **Azure** with isolated provider credentials, separated responsibility files, and plain-OS VM provisioning.

## Directory Structure

```text
cicd/terraform/
├── modules/
│   ├── hardware_sizing/   # Shared cpu_count (1, 2, 4) -> cloud instance type mapper
│   ├── compute_gcp/       # GCP Debian 12 VM + firewall + Shielded VM
│   ├── compute_aws/       # AWS EC2 + SG + dynamic AL2023 AMI + IMDSv2 + encrypted EBS
│   └── compute_azure/     # Azure VNet/Subnet/NSG/Public IP + Ubuntu 22.04 VM
└── environments/
    ├── gcp/               # Active GCP entrypoint for Jenkins Host VM (loads ONLY Google provider)
    ├── gcp-app/           # Active GCP entrypoint for Application Host VM (managed by Jenkins Pipeline)
    ├── aws/               # Ready-to-use AWS entrypoint (loads ONLY AWS provider)
    └── azure/             # Ready-to-use Azure entrypoint (loads ONLY AzureRM provider)
```

Each environment separates files by responsibility:
- `versions.tf` — Terraform & single-cloud provider version constraints
- `providers.tf` — Cloud provider configuration
- `backend.tf` — Remote state bucket & locking configuration (ready to activate)
- `variables.tf` — Input variables including the `cpu_count` hardware switch
- `main.tf` — Composition wiring `hardware_sizing` and the cloud compute module
- `outputs.tf` — Unified outputs (`vm_public_ip`, `vm_name`, `selected_machine_type`)

## Quick Start (GCP - Active)

```powershell
# 1. Initialize providers and modules
terraform -chdir=cicd/terraform/environments/gcp init

# 2. Preview changes (default: 2 vCPUs -> e2-medium)
terraform -chdir=cicd/terraform/environments/gcp plan

# 3. Scale CPU count (1 -> e2-micro, 2 -> e2-medium, 4 -> e2-standard-4)
terraform -chdir=cicd/terraform/environments/gcp apply -var="cpu_count=4"
```

## Switching to AWS or Azure Later

Simply run Terraform inside `environments/aws` or `environments/azure`. Because each environment only declares its own provider, GCP never checks AWS/Azure credentials and vice versa.

```powershell
# AWS (automatically fetches the latest Amazon Linux 2023 AMI in the selected region)
terraform -chdir=cicd/terraform/environments/aws init
terraform -chdir=cicd/terraform/environments/aws plan -var="region=us-east-1" -var="cpu_count=2"

# Azure
terraform -chdir=cicd/terraform/environments/azure init
terraform -chdir=cicd/terraform/environments/azure plan -var="ssh_public_key=ssh-ed25519 AAAA..."
```

## Enabling Remote State Locking

See `backend.tf` inside each environment (`environments/gcp/backend.tf`, `environments/aws/backend.tf`, `environments/azure/backend.tf`) for the one-time bucket creation commands and `terraform init -migrate-state`.

