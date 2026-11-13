# Firewall rule allowing SSH (22) and Jenkins UI (8080) for tagged VMs
resource "google_compute_firewall" "allow_jenkins" {
  name    = "${var.vm_name}-allow-jenkins"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["8080", "22"]
  }

  source_ranges = var.allowed_cidr_blocks
  target_tags   = ["jenkins-server"]
}

# Clean Debian 12 Compute Engine VM (no startup scripts)
resource "google_compute_instance" "this" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags   = ["jenkins-server"]
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

  metadata = {
    enable-oslogin = "TRUE"
  }
}

