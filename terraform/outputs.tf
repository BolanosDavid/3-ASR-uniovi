output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource Group name"
}

output "public_ip" {
  value       = azurerm_public_ip.main.ip_address
  description = "Public IP address"
}

output "vm_name" {
  value       = azurerm_linux_virtual_machine.main.name
  description = "Virtual Machine name"
}

output "admin_username" {
  value       = var.admin_username
  description = "VM admin username"
}
