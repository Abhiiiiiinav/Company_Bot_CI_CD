module "hardware_sizing" {
  source = "../../modules/hardware_sizing"

  cloud_provider = "aws"
  cpu_count      = var.cpu_count
}

module "vm" {
  source = "../../modules/compute_aws"

  vm_name             = var.vm_name
  machine_type        = module.hardware_sizing.machine_type
  disk_size_gb        = var.disk_size_gb
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_public_key      = var.ssh_public_key

  tags = {
    Project     = "company-bot"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

