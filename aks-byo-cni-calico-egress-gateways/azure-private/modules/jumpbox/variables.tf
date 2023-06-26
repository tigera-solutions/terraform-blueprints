variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_id" {
  description = "ID of the VNET where jumpbox VM will be installed"
  type        = string
}

variable "subnet_id" {
  description = "ID of subnet where jumpbox VM will be installed"
  type        = string
}

variable "dns_links" {
  description = "Private DNS configuration"
  type = list(object({
    name                = string
    zone_name           = string
    zone_resource_group = string
  }))
}

variable "admin_username" {
  type = string
}

variable "admin_ssh_key" {
  type = string
}
