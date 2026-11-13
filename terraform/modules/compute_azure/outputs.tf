output "vm_name" {
  description = "Name of the Azure Linux VM"
  value       = azurerm_linux_virtual_machine.this.name
}

output "vm_public_ip" {
  description = "Assigned public IP address of the Azure VM"
  value       = azurerm_public_ip.this.ip_address
}

output "vm_id" {
  description = "Azure Resource ID of the Linux VM"
  value       = azurerm_linux_virtual_machine.this.id
}

