provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {}

locals {
  name                      = var.name
  region                    = var.region
  vpc_cidr                  = var.vpc_cidr
  secondary_vpc_cidr        = var.secondary_vpc_cidr
  cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr
  azs                       = slice(data.aws_availability_zones.available.names, 0, 2)
  desired_size              = var.desired_size
  key_name                  = var.ssh_keyname
  cluster_version           = var.cluster_version
  calico_version            = var.calico_version
  pod_cidr                  = var.pod_cidr
  calico_encap              = "VXLAN"

  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = var.name
      cluster = {
        certificate-authority-data = module.eks.cluster_certificate_authority_data
        server                     = module.eks.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = var.name
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
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.10"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = slice(module.vpc.private_subnets, 0, 2)
  cluster_service_ipv4_cidr = local.cluster_service_ipv4_cidr

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    calico = {
      instance_types = ["t3.2xlarge"]

      min_size     = 0
      max_size     = 8
      desired_size = 0

      disk_size = 100

      key_name = local.key_name

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        additional               = aws_iam_policy.additional.arn
      }

      pre_bootstrap_user_data = <<-EOT
        yum install -y amazon-ssm-agent kernel-devel-`uname -r`
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
        curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum install wireguard-dkms wireguard-tools -y
        systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
      EOT

      tags = local.tags
    }
  }

  node_security_group_additional_rules = {
    ingress_to_tigera_api = {
      description                   = "Cluster API to Calico API server"
      protocol                      = "tcp"
      from_port                     = 5443
      to_port                       = 5443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_to_metrics_server = {
      description                   = "Cluster API to metrics-server"
      protocol                      = "tcp"
      from_port                     = 30000
      to_port                       = 30000
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  tags = local.tags
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

  depends_on = [
    module.eks,
    null_resource.scale_up_node_group
  ]
}

resource "aws_iam_policy" "additional" {
  name   = "${local.name}-calico-ebpf-additional"
  policy = file("${path.cwd}/min-iam-policy.json")
}

resource "null_resource" "scale_up_node_group" {
  provisioner "local-exec" {
    command = "aws eks update-nodegroup-config --cluster-name ${split(":", module.eks.eks_managed_node_groups.calico.node_group_id)[0]} --nodegroup-name ${split(":", module.eks.eks_managed_node_groups.calico.node_group_id)[1]} --scaling-config desiredSize=${local.desired_size}"
  }

  depends_on = [
    null_resource.remove_aws_node_ds,
    kubernetes_config_map.kubernetes_services_endpoint
  ]
}

resource "null_resource" "remove_aws_node_ds" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }
    command = "kubectl delete ds -n kube-system aws-node --kubeconfig <(echo $KUBECONFIG | base64 -d)"
  }

  depends_on = [
    module.eks
  ]
}

resource "null_resource" "remove_kube_proxy_ds" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }
    command = "kubectl delete ds -n kube-system kube-proxy --kubeconfig <(echo $KUBECONFIG | base64 -d)"
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_namespace" "tigera_operator" {
  metadata {
    name = "tigera-operator"
  }
}

resource "kubernetes_config_map" "kubernetes_services_endpoint" {
  metadata {
    name      = "kubernetes-services-endpoint"
    namespace = "tigera-operator"
  }

  data = {
    KUBERNETES_SERVICE_HOST = trimprefix(module.eks.cluster_endpoint, "https://")
    KUBERNETES_SERVICE_PORT = "443"
  }

  depends_on = [
    kubernetes_namespace.tigera_operator
  ]
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0.0"

  name = local.name
  cidr = local.vpc_cidr

  secondary_cidr_blocks = [local.secondary_vpc_cidr] # can add up to 5 total CIDR blocks

  azs = local.azs

  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 10)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.secondary_vpc_cidr, 4, k)]

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  intra_subnet_tags = {}

  tags = local.tags
}
