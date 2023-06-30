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
    }
  ]
}

module "hub_spoke_1_peering" {
  source                       = "./modules/vnet_peering"
  vnet_1_name                  = var.hub_vnet_name
  vnet_1_id                    = module.hub_network.vnet_id
  vnet_1_rg                    = azurerm_resource_group.vnet.name
  vnet_1_allow_gateway_transit = true
  peering_name_1_to_2          = "HubToSpoke1"
  vnet_2_name                  = var.spoke_1_vnet_name
  vnet_2_id                    = module.spoke_1_network.vnet_id
  vnet_2_rg                    = azurerm_resource_group.kube.name
  vnet_2_use_remote_gateways   = true
  peering_name_2_to_1          = "Spoke1ToHub"

  depends_on = [
    module.hub_route_server,
  ]
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
  resource_group      = azurerm_resource_group.kube.name
  location            = var.location
  rt_name             = "spoke_1-fw-rt"
  r_name              = "spoke_1-fw-r"
  firewall_private_ip = module.firewall.fw_private_ip
  subnet_id           = module.spoke_1_network.subnet_ids["aks-subnet"]
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
      peer_ip : "10.1.0.4"
    },
    {
      peer_asn : 63400
      peer_ip : "10.1.0.5"
    },
  ]
}

data "azurerm_kubernetes_service_versions" "current" {
  location       = var.location
  version_prefix = var.kube_version_prefix
}

resource "azurerm_kubernetes_cluster" "spoke_1_aks" {
  name                    = "spoke1-aks"
  location                = var.location
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name     = azurerm_resource_group.kube.name
  dns_prefix              = "aks"
  private_cluster_enabled = false

  default_node_pool {
    name           = "default"
    node_count     = var.nodepool_nodes_count
    vm_size        = var.nodepool_vm_size
    vnet_subnet_id = module.spoke_1_network.subnet_ids["aks-subnet"]
    type           = "VirtualMachineScaleSets"
    node_labels = {
      route-reflector = true
    }
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
