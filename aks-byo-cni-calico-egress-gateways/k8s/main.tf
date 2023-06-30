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
  pod_cidr                   = var.pod_cidr
  calico_version             = var.calico_version
  calico_encap               = "VXLAN"
}

################################################################################
# Calico Resources
################################################################################

resource "helm_release" "calico" {
  name             = "calico"
  chart            = "tigera-operator"
  repository       = "https://docs.projectcalico.org/charts"
  version          = local.calico_version
  namespace        = "tigera-operator"
  create_namespace = true
  values = [templatefile("${path.module}/helm_values/values-calico.yaml", {
    pod_cidr     = "${local.pod_cidr}"
    calico_encap = "${local.calico_encap}"
  })]
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

  depends_on = [
    helm_release.calico
  ]
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
  depends_on = [
    helm_release.calico
  ]
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
  depends_on = [
    helm_release.calico
  ]
}
