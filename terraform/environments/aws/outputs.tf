output "vm_public_ip" {
  description = "Assigned public IP address of the AWS EC2 instance"
  value       = module.vm.vm_public_ip
}

output "vm_name" {
  description = "Name of the AWS EC2 instance"
  value       = module.vm.vm_name
}

output "selected_machine_type" {
  description = "AWS EC2 instance type selected for the requested cpu_count"
  value       = module.hardware_sizing.machine_type
}

output "ami_id" {
  description = "Latest official Amazon Linux 2023 AMI ID resolved for the selected AWS region"
  value       = module.vm.ami_id
}

