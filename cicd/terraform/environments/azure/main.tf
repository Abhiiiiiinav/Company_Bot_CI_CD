module "hardware_sizing" {
  source = "../../modules/hardware_sizing"

  cloud_provider = "azure"
  cpu_count      = var.cpu_count
}

module "vm" {
  source = "../../modules/compute_azure"

  vm_name             = var.vm_name
  machine_type        = module.hardware_sizing.machine_type
  location            = var.location
  resource_group_name = var.resource_group_name
  disk_size_gb        = var.disk_size_gb
  allowed_cidr_blocks = var.allowed_cidr_blocks
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  admin_password      = var.admin_password

  tags = {
    Project     = "company-bot"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

