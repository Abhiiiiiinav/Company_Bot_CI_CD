module "hardware_sizing" {
  source = "../../modules/hardware_sizing"

  cloud_provider = "gcp"
  cpu_count      = var.cpu_count
}

module "vm" {
  source = "../../modules/compute_gcp"

  vm_name             = var.vm_name
  machine_type        = module.hardware_sizing.machine_type
  zone                = var.zone
  disk_size_gb        = var.disk_size_gb
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Open FastAPI (8000), Streamlit UI (8501), and SSH (22)
  allowed_ports = ["8000", "8501", "22"]
  target_tags   = ["company-bot-app"]

  # Automatically bootstrap Docker on initial boot
  startup_script = file("${path.module}/install_docker.sh")

  # SSH deployment key
  ssh_public_key = var.ssh_public_key

  labels = {
    project     = "company-bot"
    tier        = "app"
    environment = var.environment
    managed_by  = "jenkins-terraform"
  }
}
