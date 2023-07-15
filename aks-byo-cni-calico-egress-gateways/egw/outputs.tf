output "routserver_list_routes_peer_1" {
  value = "az network routeserver peering list-learned-routes --resource-group hub-network --routeserver hub-rs --name spoke-rs-bgpconnection-peer-1"
}

output "routserver_list_routes_peer_2" {
  value = "az network routeserver peering list-learned-routes --resource-group hub-network --routeserver hub-rs --name spoke-rs-bgpconnection-peer-2"
}
