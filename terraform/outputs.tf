# Lista de nombres de VM
autput "vm_names" {
  value       = local.vm_names
  description = "List of virtual machine names"
}

# Mapa de IPs públicas (vm_name => IP)
output "public_ips" {
  value       = { for name, pip in azurerm_public_ip.vm : name => pip.ip_address }
  description = "Public IP address for each VM (keyed by VM name)"
}

# Mapa de IPs privadas (vm_name => IP privada)
output "private_ips" {
  value       = { for name, nic in azurerm_network_interface.vm : name => nic.private_ip_address }
  description = "Private IP address for each VM (keyed by VM name)"
}

# Usuario administrador de SSH
output "admin_username" {
  value       = var.admin_username
  description = "VM admin username"
}