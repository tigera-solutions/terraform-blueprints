data "terraform_remote_state" "aws_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../aws/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

data "aws_region" "current" {}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }
}

locals {
  cluster_name                       = data.terraform_remote_state.aws_tfstate.outputs.cluster_name
  cluster_endpoint                   = data.terraform_remote_state.aws_tfstate.outputs.cluster_endpoint
  cluster_version                    = data.terraform_remote_state.aws_tfstate.outputs.cluster_version
  oidc_provider_arn                  = data.terraform_remote_state.aws_tfstate.outputs.oidc_provider_arn
  cluster_certificate_authority_data = data.terraform_remote_state.aws_tfstate.outputs.cluster_certificate_authority_data
  region                             = data.aws_region.current.name
  calico_enterprise_pull_secret      = data.local_sensitive_file.calico_enterprise_pull_secret.content
  calico_enterprise_license          = data.local_sensitive_file.calico_enterprise_license.content
  calico_enterprise_version          = var.calico_enterprise_version
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = local.cluster_name
      cluster = {
        certificate-authority-data = local.cluster_certificate_authority_data
        server                     = local.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = local.cluster_name
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
  })
  tags = {}
}

################################################################################
# Calico Resources
################################################################################

resource "kubernetes_namespace" "tigera-operator" {
  metadata {
    name = "tigera-operator"
  }
}

resource "helm_release" "calico_enterprise" {
  name      = "calico-enterprise"
  chart     = "https://downloads.tigera.io/ee/charts/tigera-operator-v${local.calico_enterprise_version}.tgz"
  namespace = "tigera-operator"
  values = [templatefile("${path.module}/helm_values/values-calico-enterprise.yaml", {
    calico_enterprise_pull_secret = local.calico_enterprise_pull_secret
  })]

  depends_on = [
    kubernetes_namespace.tigera-operator
  ]
}

resource "kubernetes_storage_class" "tigera-elasticsearch" {
  metadata {
    name = "tigera-elasticsearch"
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
}

resource "kubernetes_manifest" "calico_enterprise_license" {
  manifest = yamldecode(local.calico_enterprise_license)

  depends_on = [
    helm_release.calico_enterprise
  ]
}
