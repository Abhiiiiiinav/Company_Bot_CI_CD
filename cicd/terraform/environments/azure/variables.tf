# =============================================================================
# Centralized Hardware Switch
# =============================================================================

variable "cpu_count" {
  description = "Number of vCPUs (1, 2, or 4); automatically maps to Azure VM size via shared hardware_sizing module"
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2, 4], var.cpu_count)
    error_message = "cpu_count must be one of: 1, 2, 4."
  }
}

variable "disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "vm_name" {
  description = "Name assigned to the virtual machine"
  type        = string
  default     = "jenkins-vm"
}

# =============================================================================
# Azure Configuration
# =============================================================================

variable "location" {
  description = "Azure Region / Location"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
  default     = "rg-company-bot"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ports 22 and 8080 (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_username" {
  description = "Admin username for the Azure Linux VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "OpenSSH public key for the Azure Linux VM (optional if admin_password is provided)"
  type        = string
  default     = null
}

variable "admin_password" {
  description = "Admin password for the Azure Linux VM (used only if ssh_public_key is not provided)"
  type        = string
  default     = null
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment tag (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

