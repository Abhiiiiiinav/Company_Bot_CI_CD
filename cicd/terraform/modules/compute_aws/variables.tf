variable "vm_name" {
  description = "Name of the AWS EC2 instance"
  type        = string
}

variable "machine_type" {
  description = "AWS EC2 instance type (resolved from hardware_sizing module)"
  type        = string
}

variable "disk_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach ports 22 and 8080 (restrict to your IP/VPN in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_public_key" {
  description = "OpenSSH public key registered as an AWS Key Pair for SSH access (optional if using SSM)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags for billing and governance"
  type        = map(string)
  default     = {}
}

