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

  labels = {
    project     = "company-bot"
    environment = var.environment
    managed_by  = "terraform"
  }
}

