terraform {
  required_version = ">= 1.2.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.21.1"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vnet" {
  name     = var.vnet_resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "kube" {
  name     = var.kube_resource_group_name
  location = var.location
}

module "hub_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.vnet.name
  location            = var.location
  vnet_name           = var.hub_vnet_name
  address_space       = ["10.0.0.0/22"]
  subnets = [
    {
      name : "AzureFirewallSubnet"
      address_prefixes : ["10.0.0.0/24"]
    },
    {
      name : "RouteServerSubnet"
      address_prefixes : ["10.0.1.0/24"]
    },
    {
      name : "jumpbox-subnet"
      address_prefixes : ["10.0.2.0/24"]
    }
  ]
}

module "spoke_1_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.kube.name
  location            = var.location
  vnet_name           = var.spoke_1_vnet_name
  address_space       = ["10.1.0.0/22"]
  subnets = [
    {
      name : "aks-subnet"
      address_prefixes : ["10.1.0.0/24"]
    },
    {
      name : "RouteServerSubnet"
      address_prefixes : ["10.1.1.0/24"]
    },
  ]
}

module "spoke_2_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.kube.name
  location            = var.location
  vnet_name           = var.spoke_2_vnet_name
  address_space       = ["10.2.0.0/22"]
  subnets = [
    {
      name : "aks-subnet"
      address_prefixes : ["10.2.0.0/24"]
    },
    {
      name : "RouteServerSubnet"
      address_prefixes : ["10.2.1.0/24"]
    },
  ]
}

module "hub_spoke_1_peering" {
  source                         = "./modules/vnet_peering"
  vnet_1_name                    = var.hub_vnet_name
  vnet_1_id                      = module.hub_network.vnet_id
  vnet_1_rg                      = azurerm_resource_group.vnet.name
  vnet_1_allow_gateway_transit   = true
  vnet_2_name                    = var.spoke_1_vnet_name
  vnet_2_id                      = module.spoke_1_network.vnet_id
  vnet_2_rg                      = azurerm_resource_group.kube.name
  vnet_2_use_remote_gateways     = true
  peering_name_1_to_2            = "HubToSpoke1"
  peering_name_2_to_1            = "Spoke1ToHub"
}

module "hub_spoke_2_peering" {
  source                         = "./modules/vnet_peering"
  vnet_1_name                    = var.hub_vnet_name
  vnet_1_id                      = module.hub_network.vnet_id
  vnet_1_rg                      = azurerm_resource_group.vnet.name
  vnet_1_allow_gateway_transit   = true
  vnet_2_name                    = var.spoke_2_vnet_name
  vnet_2_id                      = module.spoke_2_network.vnet_id
  vnet_2_rg                      = azurerm_resource_group.kube.name
  vnet_2_use_remote_gateways     = true
  peering_name_1_to_2            = "HubToSpoke2"
  peering_name_2_to_1            = "Spoke2ToHub"
}

module "spoke_1_spoke_2_peering" {
  source              = "./modules/vnet_peering"
  vnet_1_name         = var.spoke_1_vnet_name
  vnet_1_id           = module.spoke_1_network.vnet_id
  vnet_1_rg           = azurerm_resource_group.kube.name
  vnet_2_name         = var.spoke_2_vnet_name
  vnet_2_id           = module.spoke_2_network.vnet_id
  vnet_2_rg           = azurerm_resource_group.kube.name
  peering_name_1_to_2 = "Spoke1ToSpoke2"
  peering_name_2_to_1 = "Spoke2ToSpoke1"
}

module "firewall" {
  source         = "./modules/firewall"
  resource_group = azurerm_resource_group.vnet.name
  location       = var.location
  pip_name       = "azureFirewalls-ip"
  fw_name        = "kubenetfw"
  subnet_id      = module.hub_network.subnet_ids["AzureFirewallSubnet"]
}

module "spoke_1_routetable" {
  source              = "./modules/route_table"
  resource_group      = azurerm_resource_group.vnet.name
  location            = var.location
  rt_name             = "spoke_1-fw-rt"
  r_name              = "spoke_1-fw-r"
  firewall_private_ip = module.firewall.fw_private_ip
  subnet_id           = module.spoke_1_network.subnet_ids["aks-subnet"]
}

module "spoke_2_routetable" {
  source              = "./modules/route_table"
  resource_group      = azurerm_resource_group.vnet.name
  location            = var.location
  rt_name             = "spoke-2-fw-rt"
  r_name              = "spoke-2-fw-r"
  firewall_private_ip = module.firewall.fw_private_ip
  subnet_id           = module.spoke_2_network.subnet_ids["aks-subnet"]
}

module "hub_route_server" {
  source         = "./modules/route_server"
  resource_group = azurerm_resource_group.vnet.name
  location       = var.location
  subnet_id      = module.hub_network.subnet_ids["RouteServerSubnet"]
  rs_name        = "hub-rs"
  rs_pip_name    = "hub-rs-pip"
  bgp_peers = [
    {
      peer_asn : 63400
      peer_ip : "10.0.1.5"
    },
    {
      peer_asn : 63400
      peer_ip : "10.0.1.6"
    },
  ]
}

data "azurerm_kubernetes_service_versions" "current" {
  location       = var.location
  version_prefix = var.kube_version_prefix
}

resource "azurerm_kubernetes_cluster" "spoke_1_privateaks" {
  name                    = "spoke1-private-aks"
  location                = var.location
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name     = azurerm_resource_group.kube.name
  dns_prefix              = "private-aks"
  private_cluster_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = var.nodepool_nodes_count
    vm_size        = var.nodepool_vm_size
    vnet_subnet_id = module.spoke_1_network.subnet_ids["aks-subnet"]
    type           = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = var.admin_username
    ssh_key {
      key_data = var.admin_ssh_key
    }
  }

  network_profile {
    network_plugin     = "none"
    service_cidr       = var.network_service_cidr
    dns_service_ip     = var.network_dns_service_ip
    docker_bridge_cidr = var.network_docker_bridge_cidr
    outbound_type      = "userDefinedRouting"
  }

  depends_on = [module.spoke_1_routetable]
}

resource "azurerm_kubernetes_cluster" "spoke_2_privateaks" {
  name                    = "spoke2-private-aks"
  location                = var.location
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name     = azurerm_resource_group.kube.name
  dns_prefix              = "private-aks"
  private_cluster_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = var.nodepool_nodes_count
    vm_size        = var.nodepool_vm_size
    vnet_subnet_id = module.spoke_2_network.subnet_ids["aks-subnet"]
    type           = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = var.admin_username
    ssh_key {
      key_data = var.admin_ssh_key
    }
  }

  network_profile {
    network_plugin     = "none"
    service_cidr       = var.network_service_cidr
    dns_service_ip     = var.network_dns_service_ip
    docker_bridge_cidr = var.network_docker_bridge_cidr
    outbound_type      = "userDefinedRouting"
  }

  depends_on = [module.spoke_2_routetable]
}

resource "azurerm_role_assignment" "spoke_1_netcontributor" {
  role_definition_name = "Network Contributor"
  scope                = module.spoke_1_network.subnet_ids["aks-subnet"]
  principal_id         = azurerm_kubernetes_cluster.spoke_1_privateaks.identity[0].principal_id
}

resource "azurerm_role_assignment" "spoke_2_netcontributor" {
  role_definition_name = "Network Contributor"
  scope                = module.spoke_2_network.subnet_ids["aks-subnet"]
  principal_id         = azurerm_kubernetes_cluster.spoke_2_privateaks.identity[0].principal_id
}

module "jumpbox" {
  admin_username = var.admin_username
  admin_ssh_key  = var.admin_ssh_key
  source         = "./modules/jumpbox"
  location       = var.location
  resource_group = azurerm_resource_group.vnet.name
  vnet_id        = module.hub_network.vnet_id
  subnet_id      = module.hub_network.subnet_ids["jumpbox-subnet"]
  dns_links = [
    {
      name : "spoke1-link"
      zone_name : join(".", slice(split(".", azurerm_kubernetes_cluster.spoke_1_privateaks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.spoke_1_privateaks.private_fqdn))))
      zone_resource_group : azurerm_kubernetes_cluster.spoke_1_privateaks.node_resource_group
    },
    {
      name : "spoke2-link"
      zone_name : join(".", slice(split(".", azurerm_kubernetes_cluster.spoke_2_privateaks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.spoke_2_privateaks.private_fqdn))))
      zone_resource_group : azurerm_kubernetes_cluster.spoke_2_privateaks.node_resource_group
    },
  ]
}
