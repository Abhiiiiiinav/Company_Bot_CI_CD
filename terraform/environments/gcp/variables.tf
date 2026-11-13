# =============================================================================
# Centralized Hardware Switch
# =============================================================================

variable "cpu_count" {
  description = "Number of vCPUs (1, 2, or 4); automatically maps to GCP machine type via shared hardware_sizing module"
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2, 4], var.cpu_count)
    error_message = "cpu_count must be one of: 1, 2, 4."
  }
}

variable "disk_size_gb" {
  description = "OS boot disk size in GB"
  type        = number
  default     = 30
}

variable "vm_name" {
  description = "Name assigned to the virtual machine"
  type        = string
  default     = "jenkins-vm"
}

# =============================================================================
# GCP Configuration
# =============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "company-bot11"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ports 22 and 8080 (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "environment" {
  description = "Deployment environment label (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

