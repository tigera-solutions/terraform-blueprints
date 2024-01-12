terraform {
  required_version = ">= 1.2.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.21.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.1"
    }
  }
}

data "azurerm_kubernetes_cluster" "credentials" {
  depends_on          = [azurerm_kubernetes_cluster.aks]
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.vnet.name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.credentials.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_config.0.cluster_ca_certificate)
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vnet" {
  name     = var.vnet_resource_group_name
  location = var.location
}

module "aks_network" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.vnet.name
  location            = var.location
  vnet_name           = var.aks_vnet_name
  address_space       = ["10.0.0.0/22"]
  subnets = [
    {
      name : "aks-subnet"
      address_prefixes : ["10.0.0.0/24"]
    }
  ]
}

data "azurerm_kubernetes_service_versions" "current" {
  location       = var.location
  version_prefix = var.kube_version_prefix
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.cluster_name
  location                = var.location
  kubernetes_version      = data.azurerm_kubernetes_service_versions.current.latest_version
  resource_group_name     = azurerm_resource_group.vnet.name
  dns_prefix              = "aks"
  private_cluster_enabled = false

  default_node_pool {
    name           = "default"
    node_count     = var.nodepool_nodes_count
    vm_size        = var.nodepool_vm_size
    vnet_subnet_id = module.aks_network.subnet_ids["aks-subnet"]
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
  }
}

resource "azurerm_role_assignment" "netcontributor" {
  role_definition_name = "Network Contributor"
  scope                = module.aks_network.subnet_ids["aks-subnet"]
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "kubernetes_namespace" "tigera_operator" {
  metadata {
    name = "tigera-operator"
  }
}

resource "kubernetes_namespace" "calico_system" {
  metadata {
    name = "calico-system"
  }
}

resource "helm_release" "calico" {
  name       = "calico"
  chart      = "tigera-operator"
  repository = "https://docs.projectcalico.org/charts"
  version    = "v3.26.4"
  namespace  = "tigera-operator"
  values = [templatefile("${path.module}/helm_values/values-calico.yaml", {
    pod_cidr = "${var.cluster_pod_cidr}"
  })]

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    kubernetes_namespace.tigera_operator,
    kubernetes_namespace.calico_system,
  ]
}

resource "null_resource" "remove_finalizers" {
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl delete installations.operator.tigera.io default"
  }

  triggers = {
    helm_tigera = helm_release.calico.status
  }

  depends_on = [
    helm_release.calico
  ]
}
