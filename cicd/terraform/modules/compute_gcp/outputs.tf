output "vm_name" {
  description = "Name of the GCP VM instance"
  value       = google_compute_instance.this.name
}

output "vm_public_ip" {
  description = "Assigned ephemeral public IP of the GCP VM"
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}

output "vm_id" {
  description = "Self-link ID of the GCP VM instance"
  value       = google_compute_instance.this.id
}

