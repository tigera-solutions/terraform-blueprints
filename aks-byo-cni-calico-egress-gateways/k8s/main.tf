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
