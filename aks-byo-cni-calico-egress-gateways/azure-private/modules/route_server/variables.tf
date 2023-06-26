variable "rs_name" {
  description = "route server name"
  type        = string
}

variable "rs_pip_name" {
  description = "route server public ip name"
  type        = string
}

variable "resource_group" {
  description = "Resource Group name"
  type        = string
}

variable "location" {
  description = "Location in which to deploy the route server"
  type        = string
}

variable "subnet_id" {
  description = "ID of subnet where route server will be installed"
  type        = string
}

variable "bgp_peers" {
  description = "BGP peers"
  type = list(object({
    peer_ip  = string
    peer_asn = string
  }))
}
