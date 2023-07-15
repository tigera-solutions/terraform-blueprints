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
