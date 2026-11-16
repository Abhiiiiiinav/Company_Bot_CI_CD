output "app_public_ip" {
  description = "Assigned public IP address of the application VM"
  value       = module.vm.vm_public_ip
}

output "app_vm_name" {
  description = "Name of the application VM"
  value       = module.vm.vm_name
}

output "selected_machine_type" {
  description = "GCP machine type selected for the requested cpu_count"
  value       = module.hardware_sizing.machine_type
}

output "ui_url" {
  description = "Public URL for Streamlit frontend"
  value       = "http://${module.vm.vm_public_ip}:8501"
}

output "api_url" {
  description = "Public URL for FastAPI backend"
  value       = "http://${module.vm.vm_public_ip}:8000"
}
