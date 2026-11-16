# =============================================================================
# Centralized Hardware Switch (Application Host)
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
  description = "OS boot disk size in GB (sized for Docker images and ChromaDB data)"
  type        = number
  default     = 40
}

variable "vm_name" {
  description = "Name assigned to the application virtual machine"
  type        = string
  default     = "company-bot-app"
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
  description = "CIDR blocks allowed to access application ports (8000, 8501, 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "environment" {
  description = "Deployment environment label (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "ssh_public_key" {
  description = "Public SSH key for Jenkins to deploy application onto the VM"
  type        = string
  default     = null
}

