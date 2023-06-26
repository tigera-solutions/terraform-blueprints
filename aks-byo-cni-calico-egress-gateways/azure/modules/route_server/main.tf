resource "azurerm_public_ip" "spoke_pub_ip" {
  name                = var.rs_pip_name
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "spoke_rs" {
  name                             = var.rs_name
  location                         = var.location
  resource_group_name              = var.resource_group
  subnet_id                        = var.subnet_id
  public_ip_address_id             = azurerm_public_ip.spoke_pub_ip.id
  branch_to_branch_traffic_enabled = false
  sku                              = "Standard"
}

resource "azurerm_route_server_bgp_connection" "spoke_rs_bgp_peer" {
  for_each = { for peer in var.bgp_peers : peer.peer_ip => peer.peer_asn }

  name            = "spoke-rs-bgpconnection-peer-${index(var.bgp_peers.*.peer_ip, each.key) + 1}"
  route_server_id = azurerm_route_server.spoke_rs.id
  peer_ip         = each.key
  peer_asn        = each.value
}
