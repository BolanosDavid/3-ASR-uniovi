variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "prefix" {
  type        = string
  description = "Resource naming prefix"
}

variable "vm_size" {
  type        = string
  description = "VM size"
}

variable "admin_username" {
  type        = string
  description = "VM admin username"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed for SSH access"
}

variable "vm_count" {
  type        = number
  description = "Number of virtual machines to deploy"
  default     = 3
}