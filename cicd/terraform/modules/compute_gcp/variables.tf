variable "vm_name" {
  description = "Name of the GCP Compute Engine instance"
  type        = string
}

variable "machine_type" {
  description = "GCP machine type (resolved from hardware_sizing module)"
  type        = string
}

variable "zone" {
  description = "GCP Zone where the VM will be provisioned"
  type        = string
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "disk_type" {
  description = "GCP persistent disk type (pd-balanced recommended for CI/general workloads)"
  type        = string
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.disk_type)
    error_message = "disk_type must be one of: pd-standard, pd-balanced, pd-ssd."
  }
}

variable "network_name" {
  description = "GCP VPC network name"
  type        = string
  default     = "default"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach exposed ports (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ports" {
  description = "TCP ports allowed through the firewall (e.g. ['22', '8080'] for Jenkins or ['22', '8000', '8501'] for apps)"
  type        = list(string)
  default     = ["8080", "22"]
}

variable "target_tags" {
  description = "Network tags applied to the VM and matched by the firewall rule"
  type        = list(string)
  default     = ["jenkins-server"]
}

variable "startup_script" {
  description = "Optional bash script to execute on VM startup"
  type        = string
  default     = null
}

variable "labels" {
  description = "Resource labels for billing and governance (lowercase keys/values)"
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "Optional service account email to attach to the VM instance (e.g. for Jenkins VM)"
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "OAuth scopes granted to the attached service account"
  type        = list(string)
  default     = ["cloud-platform"]
}

variable "ssh_public_key" {
  description = "Optional SSH public key for deployer user (bypasses OS Login for automated CI/CD SSH access)"
  type        = string
  default     = null
}



