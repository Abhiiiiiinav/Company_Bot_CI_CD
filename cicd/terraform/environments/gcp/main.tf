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

  # Automatically bootstrap Docker, Jenkins container, and Terraform CLI on initial boot
  startup_script = file("${path.module}/install_jenkins.sh")

  # Attach service account with compute/storage permissions for CI/CD automation
  service_account_email = "jenkins-terraform-sa@company-bot11.iam.gserviceaccount.com"

  labels = {
    project     = "company-bot"
    environment = var.environment
    managed_by  = "terraform"
  }
}

