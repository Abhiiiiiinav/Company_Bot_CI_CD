variable "cloud_provider" {
  description = "Target cloud provider (gcp, aws, or azure)"
  type        = string

  validation {
    condition     = contains(["gcp", "aws", "azure"], var.cloud_provider)
    error_message = "cloud_provider must be one of: gcp, aws, azure."
  }
}

variable "cpu_count" {
  description = "Centralized vCPU count (1, 2, or 4) mapped to cloud-native instance families"
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2, 4], var.cpu_count)
    error_message = "cpu_count must be one of: 1, 2, 4."
  }
}

