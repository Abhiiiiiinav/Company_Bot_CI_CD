output "vm_name" {
  description = "Name tag of the AWS EC2 instance"
  value       = aws_instance.this.tags["Name"]
}

output "vm_public_ip" {
  description = "Assigned public IP address of the AWS EC2 instance"
  value       = aws_instance.this.public_ip
}

output "vm_id" {
  description = "AWS EC2 instance ID"
  value       = aws_instance.this.id
}

output "ami_id" {
  description = "Dynamically resolved Amazon Linux 2023 AMI ID"
  value       = data.aws_ami.al2023.id
}

