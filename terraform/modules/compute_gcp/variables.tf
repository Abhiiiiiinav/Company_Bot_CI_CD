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
  description = "CIDR blocks allowed to reach ports 22 and 8080 (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "labels" {
  description = "Resource labels for billing and governance (lowercase keys/values)"
  type        = map(string)
  default     = {}
}

