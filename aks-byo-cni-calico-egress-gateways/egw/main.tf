data "terraform_remote_state" "azure_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../azure/terraform.tfstate"
  }
}

provider "kubernetes" {
  host                   = local.cluster_host
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
  client_certificate     = base64decode(local.cluster_client_certificate)
  client_key             = base64decode(local.cluster_client_key)
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_host
    cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
    client_certificate     = base64decode(local.cluster_client_certificate)
    client_key             = base64decode(local.cluster_client_key)
  }
}

locals {
  cluster_host               = data.terraform_remote_state.azure_tfstate.outputs.cluster_host
  cluster_ca_certificate     = data.terraform_remote_state.azure_tfstate.outputs.cluster_ca_certificate
  cluster_client_certificate = data.terraform_remote_state.azure_tfstate.outputs.cluster_client_certificate
  cluster_client_key         = data.terraform_remote_state.azure_tfstate.outputs.cluster_client_key
  cluster_kube_config        = data.terraform_remote_state.azure_tfstate.outputs.cluster_kube_config
}

################################################################################
# Calico Resources
################################################################################

resource "kubernetes_manifest" "bgpconfiguration_default" {
  manifest = {
    "apiVersion" = "projectcalico.org/v3"
    "kind" = "BGPConfiguration"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "asNumber" = 63400
      "logSeverityScreen" = "Info"
      "nodeToNodeMeshEnabled" = false
    }
  }
}

resource "kubernetes_manifest" "bgppeer_peer_with_route_reflectors" {
  manifest = {
    "apiVersion" = "projectcalico.org/v3"
    "kind" = "BGPPeer"
    "metadata" = {
      "name" = "peer-with-route-reflectors"
    }
    "spec" = {
      "nodeSelector" = "all()"
      "peerSelector" = "route-reflector == 'true'"
    }
  }
}

resource "kubernetes_manifest" "bgppeer_azure_route_server_a" {
  manifest = {
    "apiVersion" = "projectcalico.org/v3"
    "kind" = "BGPPeer"
    "metadata" = {
      "name" = "azure-route-server-a"
    }
    "spec" = {
      "asNumber" = 65515
      "keepOriginalNextHop" = true
      "nodeSelector" = "route-reflector == 'true'"
      "peerIP" = "10.0.1.4"
      "reachableBy" = "10.1.0.1"
    }
  }
}

resource "kubernetes_manifest" "bgppeer_azure_route_server_b" {
  manifest = {
    "apiVersion" = "projectcalico.org/v3"
    "kind" = "BGPPeer"
    "metadata" = {
      "name" = "azure-route-server-b"
    }
    "spec" = {
      "asNumber" = 65515
      "keepOriginalNextHop" = true
      "nodeSelector" = "route-reflector == 'true'"
      "peerIP" = "10.0.1.5"
      "reachableBy" = "10.1.0.1"
    }
  }
}
