variable "location" {
  description = "The resource group location"
  default     = "East US"
}

variable "vnet_resource_group_name" {
  description = "The resource group name to be created"
  default     = "aks-azure-cni-overlay-networking"
}

variable "admin_username" {
  description = "Admin username"
  default     = "azureuser"
}

variable "admin_ssh_key" {
  description = "Admin SSH public key"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsi+rMbWujrAJbRyee4wLwB7qWVG3VzZdSj3xlfdnZaMp2PBKjhryAljF9jwVuzQKsNDjkWfxGEmCsUJ9GU0m9PSrLZC78etd3FivEnihZumAlUzkGDq+WgMqOyWPhfCikNqldlnkS4BB0IdwNej8RuDj6OEzvyJDvfGzjBtj6sR2hAaUM7KBh6MCu/BXOsbKF+/A5LwaZylDD1kBjXqEdLth9qgw11SyO2b5na3HHu2a13jOPbCuqKTKzvmxIadb1Eo/eV8sq/AnjmPK4y0qOD6KyqsOEpPjlqIbH7FJIL0nhRcaKVfD1HNKLlSmOWKSG8cimmJimBgw84OPIAc0v demo@example.com"
}

variable "aks_vnet_name" {
  description = "VNET name"
  default     = "aks-vnet"
}

variable "cluster_name" {
  description = "AKS cluster name"
  default     = "aks-azure-cni-overlay"
}

variable "kube_version_prefix" {
  description = "AKS Kubernetes version prefix. Formatted '[Major].[Minor]' like '1.18'. Patch version part (as in '[Major].[Minor].[Patch]') will be set to latest automatically."
  default     = "1.25"
}

variable "nodepool_nodes_count" {
  description = "Default nodepool nodes count"
  default     = 3
}

variable "nodepool_vm_size" {
  description = "Default nodepool VM size"
  default     = "Standard_B2ms"
}

variable "network_dns_service_ip" {
  description = "CNI DNS service IP"
  default     = "10.9.0.10"
}

variable "network_service_cidr" {
  description = "CNI service cidr"
  default     = "10.9.0.0/16"
}

variable "network_docker_bridge_cidr" {
  description = "Docker bridge cidr"
  default     = "172.17.0.1/16"
}
