# =============================================================================
# Centralized Hardware Switch
# =============================================================================

variable "cpu_count" {
  description = "Number of vCPUs (1, 2, or 4); automatically maps to AWS instance type via shared hardware_sizing module"
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2, 4], var.cpu_count)
    error_message = "cpu_count must be one of: 1, 2, 4."
  }
}

variable "disk_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "vm_name" {
  description = "Name tag assigned to the EC2 instance"
  type        = string
  default     = "jenkins-vm"
}

# =============================================================================
# AWS Configuration
# =============================================================================

variable "region" {
  description = "AWS Region (the latest Amazon Linux 2023 AMI is automatically queried for this region)"
  type        = string
  default     = "ap-south-1"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ports 22 and 8080 (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_public_key" {
  description = "OpenSSH public key for SSH login to the AWS EC2 instance"
  type        = string
  default     = null
}

variable "environment" {
  description = "Deployment environment tag (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

