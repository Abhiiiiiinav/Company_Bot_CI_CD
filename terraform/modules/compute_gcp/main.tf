# Firewall rule allowing specified ports (SSH, Jenkins, or App ports) for tagged VMs
resource "google_compute_firewall" "allow_jenkins" {
  name    = "${var.vm_name}-ingress"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  source_ranges = var.allowed_cidr_blocks
  target_tags   = var.target_tags
}

# Debian 12 Compute Engine VM
resource "google_compute_instance" "this" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags   = var.target_tags
  labels = var.labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.disk_size_gb
      type  = var.disk_type
    }
  }

  network_interface {
    network = var.network_name

    # Assigns an ephemeral external public IP
    access_config {}
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata_startup_script = var.startup_script

  dynamic "service_account" {
    for_each = var.service_account_email != null ? [var.service_account_email] : []
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }

  metadata = var.ssh_public_key != null ? {
    enable-oslogin = "FALSE"
    ssh-keys       = "deployer:${var.ssh_public_key}"
  } : {
    enable-oslogin = "TRUE"
  }
}

