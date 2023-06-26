resource "azurerm_virtual_network_peering" "peering" {
  name                         = var.peering_name_1_to_2
  resource_group_name          = var.vnet_1_rg
  virtual_network_name         = var.vnet_1_name
  remote_virtual_network_id    = var.vnet_2_id
  allow_virtual_network_access = var.vnet_1_allow_virtual_network_access
  allow_forwarded_traffic      = var.vnet_1_allow_forwarded_traffic
  allow_gateway_transit        = var.vnet_1_allow_gateway_transit
  use_remote_gateways          = var.vnet_1_use_remote_gateways
}

resource "azurerm_virtual_network_peering" "peering-back" {
  name                         = var.peering_name_2_to_1
  resource_group_name          = var.vnet_2_rg
  virtual_network_name         = var.vnet_2_name
  remote_virtual_network_id    = var.vnet_1_id
  allow_virtual_network_access = var.vnet_2_allow_virtual_network_access
  allow_forwarded_traffic      = var.vnet_2_allow_forwarded_traffic
  allow_gateway_transit        = var.vnet_2_allow_gateway_transit
  use_remote_gateways          = var.vnet_2_use_remote_gateways
}
