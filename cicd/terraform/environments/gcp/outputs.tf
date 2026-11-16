output "vm_public_ip" {
  description = "Assigned public IP address of the GCP VM"
  value       = module.vm.vm_public_ip
}

output "vm_name" {
  description = "Name of the GCP VM"
  value       = module.vm.vm_name
}

output "selected_machine_type" {
  description = "GCP machine type selected for the requested cpu_count"
  value       = module.hardware_sizing.machine_type
}

