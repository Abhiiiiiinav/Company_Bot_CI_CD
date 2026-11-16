variable "vm_name" {
  description = "Name of the Azure Linux VM"
  type        = string
}

variable "machine_type" {
  description = "Azure VM size (resolved from hardware_sizing module)"
  type        = string
}

variable "location" {
  description = "Azure region / location"
  type        = string
}

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "storage_account_type" {
  description = "Azure managed disk SKU (StandardSSD_LRS recommended over HDD Standard_LRS)"
  type        = string
  default     = "StandardSSD_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.storage_account_type)
    error_message = "storage_account_type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach ports 22 and 8080 (restrict to your IP/VPN in production)"
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

variable "tags" {
  description = "Resource tags for billing and governance"
  type        = map(string)
  default     = {}
}

