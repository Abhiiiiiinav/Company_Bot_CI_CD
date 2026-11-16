locals {
  machine_sizes = {
    gcp = {
      1 = "e2-micro"
      2 = "e2-medium"
      4 = "e2-standard-4"
    }
    aws = {
      1 = "t3.micro"
      2 = "t3.medium"
      4 = "t3.xlarge"
    }
    azure = {
      1 = "Standard_B1s"
      2 = "Standard_B2s"
      4 = "Standard_B4ms"
    }
  }

  selected_machine_type = local.machine_sizes[var.cloud_provider][var.cpu_count]
}

