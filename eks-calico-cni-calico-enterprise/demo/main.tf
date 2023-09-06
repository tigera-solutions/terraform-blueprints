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
  multi_cluster_management_fqdn      = var.multi_cluster_management_fqdn
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
# Demo Resources
################################################################################

# Network load balancer to expose the tigera-manager ui
resource "kubernetes_service" "tigera-manager-lb" {
  metadata {
    name      = "tigera-manager-lb"
    namespace = "tigera-manager"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"             = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type"               = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"    = "instance"
      "service.beta.kubernetes.io/aws-load-balancer-target-node-labels" = "kubernetes.io/os=linux"
    }
  }
  spec {
    selector = {
      k8s-app = "tigera-manager"
    }
    port {
      port        = 443
      target_port = 9443
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}

# Network load balancer to expose the tigera-manager mcm service
resource "kubernetes_service" "tigera-mcm-lb" {
  metadata {
    name      = "tigera-mcm-lb"
    namespace = "tigera-manager"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"             = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type"               = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"    = "instance"
      "service.beta.kubernetes.io/aws-load-balancer-target-node-labels" = "kubernetes.io/os=linux"
    }
  }
  spec {
    selector = {
      k8s-app = "tigera-manager"
    }
    port {
      port        = 443
      target_port = 9449
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}

# Calico Enterprise Multi Cluster Management endpoint
resource "kubernetes_manifest" "managementcluster_tigera_secure" {
  manifest = {
    "apiVersion" = "operator.tigera.io/v1"
    "kind"       = "ManagementCluster"
    "metadata" = {
      "name" = "tigera-secure"
    }
    "spec" = {
      "address" = "${local.multi_cluster_management_fqdn}:443"
    }
  }
}

# ServiceAccount for us to Login to the Tigera Manager UI
resource "kubernetes_service_account" "tigera_admin_team" {
  metadata {
    name      = "tigera-admin-team"
    namespace = "default"
  }
}

# ServiceAccount token for authentication
resource "kubernetes_secret" "tigera_admin_team" {
  metadata {
    name      = "tigera-admin-team"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = "tigera-admin-team"
    }
  }
  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.tigera_admin_team,
  ]
}

# Give tigera-admin-team administrative rights in the Tigera Manager UI
resource "kubernetes_cluster_role_binding" "tigera_admin_team_access" {
  metadata {
    name = "terraform-admin-team-access"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "tigera-network-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tigera-admin-team"
    namespace = "default"
  }

  depends_on = [
    kubernetes_service_account.tigera_admin_team,
  ]
}
