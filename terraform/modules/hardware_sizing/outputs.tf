output "machine_type" {
  description = "Resolved cloud-native machine/instance type for the given cloud_provider and cpu_count"
  value       = local.selected_machine_type
}

