# Provider Configuration for Region 1
provider "aws" {
  alias  = "region1"
  region = var.region1
}

# Provider Configuration for Region 2
provider "aws" {
  alias  = "region2"
  region = var.region2
}

# Fetch Available Availability Zones in Region 1
data "aws_availability_zones" "available_region1" {
  provider = aws.region1
}

# Fetch Available Availability Zones in Region 2
data "aws_availability_zones" "available_region2" {
  provider = aws.region2
}

# Fetch EKS Cluster Auth Data for Cluster 1
data "aws_eks_cluster_auth" "cluster1_auth" {
  name = module.eks_cluster1.cluster_name
}

# Fetch EKS Cluster Auth Data for Cluster 2
data "aws_eks_cluster_auth" "cluster2_auth" {
  name = module.eks_cluster2.cluster_name
}

# Local Variables
locals {
  azs_region1 = slice(data.aws_availability_zones.available_region1.names, 0, 2)
  azs_region2 = slice(data.aws_availability_zones.available_region2.names, 0, 2)

  route_table_map_vpc1 = { for idx, rt_id in module.vpc1.private_route_table_ids : tostring(idx) => rt_id }
  route_table_map_vpc2 = { for idx, rt_id in module.vpc2.private_route_table_ids : tostring(idx) => rt_id }

  # Kubeconfig for EKS Cluster 1
  kubeconfig_cluster1 = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform-${var.cluster1_name}"
    clusters = [{
      name = var.cluster1_name
      cluster = {
        certificate-authority-data = module.eks_cluster1.cluster_certificate_authority_data
        server                     = module.eks_cluster1.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform-${var.cluster1_name}"
      context = {
        cluster = var.cluster1_name
        user    = "terraform-${var.cluster1_name}"
      }
    }]
    users = [{
      name = "terraform-${var.cluster1_name}"
      user = {
        token = data.aws_eks_cluster_auth.cluster1_auth.token
      }
    }]
  })

  # Kubeconfig for EKS Cluster 2
  kubeconfig_cluster2 = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform-${var.cluster2_name}"
    clusters = [{
      name = var.cluster2_name
      cluster = {
        certificate-authority-data = module.eks_cluster2.cluster_certificate_authority_data
        server                     = module.eks_cluster2.cluster_endpoint
      }
    }]
    contexts = [{
      name = "terraform-${var.cluster2_name}"
      context = {
        cluster = var.cluster2_name
        user    = "terraform-${var.cluster2_name}"
      }
    }]
    users = [{
      name = "terraform-${var.cluster2_name}"
      user = {
        token = data.aws_eks_cluster_auth.cluster2_auth.token
      }
    }]
  })
}

# Configuration for VPC 1 in Region 1
module "vpc1" {
  source    = "terraform-aws-modules/vpc/aws"
  providers = { aws = aws.region1 }
  version   = ">= 5.0.0"

  name = var.cluster1_name
  cidr = var.vpc1_cidr
  azs  = local.azs_region1

  public_subnets  = [for k, v in local.azs_region1 : cidrsubnet(var.vpc1_cidr, 4, k)]
  private_subnets = [for k, v in local.azs_region1 : cidrsubnet(var.vpc1_cidr, 4, k + 10)]

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster1_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster1_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster1_name}-default" }

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
}

# Configuration for VPC 2 in Region 2
module "vpc2" {
  source    = "terraform-aws-modules/vpc/aws"
  providers = { aws = aws.region2 }
  version   = ">= 5.0.0"

  name = var.cluster2_name
  cidr = var.vpc2_cidr
  azs  = local.azs_region2

  public_subnets  = [for k, v in local.azs_region2 : cidrsubnet(var.vpc2_cidr, 4, k)]
  private_subnets = [for k, v in local.azs_region2 : cidrsubnet(var.vpc2_cidr, 4, k + 10)]

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster2_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster2_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster2_name}-default" }

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
}

# VPC Peering Connection between VPC 1 and VPC 2
resource "aws_vpc_peering_connection" "vpc_peering" {
  provider = aws.region1

  vpc_id      = module.vpc1.vpc_id
  peer_vpc_id = module.vpc2.vpc_id
  peer_region = var.region2
  auto_accept = false

  tags = {
    Name = "VPC Peering between ${var.cluster1_name} and ${var.cluster2_name}"
  }
}

# Accept the VPC Peering Connection in the accepter region
resource "aws_vpc_peering_connection_accepter" "accepter" {
  provider                  = aws.region2
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
  auto_accept               = true

  tags = {
    Name = "Accept VPC Peering between ${var.cluster1_name} and ${var.cluster2_name}"
  }
}

# Create routes for VPC 1 to communicate with VPC 2
resource "aws_route" "vpc1_to_vpc2" {
  for_each                  = local.route_table_map_vpc1
  provider                  = aws.region1
  route_table_id            = each.value
  destination_cidr_block    = var.vpc2_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Create routes for VPC 2 to communicate with VPC 1
resource "aws_route" "vpc2_to_vpc1" {
  for_each                  = local.route_table_map_vpc2
  provider                  = aws.region2
  route_table_id            = each.value
  destination_cidr_block    = var.vpc1_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# EKS Cluster 1 Configuration
module "eks_cluster1" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "~> 19.10"
  providers                      = { aws = aws.region1 }
  cluster_name                   = var.cluster1_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true
  vpc_id                         = module.vpc1.vpc_id
  subnet_ids                     = slice(module.vpc1.private_subnets, 0, 2)

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    calico = {
      name          = var.cluster1_name
      desired_size  = 0
      max_size      = 8
      min_size      = 0
      instance_type = var.instance_type
      disk_size     = 100
      key_name      = var.ssh_keyname
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        additional               = aws_iam_policy.additional_cluster1.arn
      }
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
    ingress_to_tigera_image_assurance_admission_controller = {
      description                   = "Cluster API to Tigera Admission Controller"
      protocol                      = "tcp"
      from_port                     = 8080
      to_port                       = 8080
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
    ingress_from_cluster2_vpc = {
      description = "Allow VXLAN traffic from Cluster 2 VPC CIDR"
      protocol    = "udp"
      from_port   = 4789
      to_port     = 4789
      type        = "ingress"
      cidr_blocks = [var.vpc2_cidr]
    }
  }
}

# EKS Cluster 2 Configuration
module "eks_cluster2" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "~> 19.10"
  providers                      = { aws = aws.region2 }
  cluster_name                   = var.cluster2_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true
  vpc_id                         = module.vpc2.vpc_id
  subnet_ids                     = slice(module.vpc2.private_subnets, 0, 2)

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    calico = {
      name          = var.cluster2_name
      desired_size  = 0
      max_size      = 8
      min_size      = 0
      instance_type = var.instance_type
      disk_size     = 100
      key_name      = var.ssh_keyname
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        additional               = aws_iam_policy.additional_cluster2.arn
      }
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
    ingress_to_tigera_image_assurance_admission_controller = {
      description                   = "Cluster API to Tigera Admission Controller"
      protocol                      = "tcp"
      from_port                     = 8080
      to_port                       = 8080
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
    ingress_from_cluster1_vpc = {
      description = "Allow VXLAN traffic from Cluster 1 VPC CIDR"
      protocol    = "udp"
      from_port   = 4789
      to_port     = 4789
      type        = "ingress"
      cidr_blocks = [var.vpc1_cidr]
    }
  }
}

# Kubernetes and Helm provider for EKS Cluster 1
provider "kubernetes" {
  alias = "region1"

  host                   = module.eks_cluster1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster1.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks_cluster1.cluster_name,
      "--region",
      var.region1
    ]
  }
}

provider "helm" {
  alias = "region1"

  kubernetes {
    host                   = module.eks_cluster1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster1.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks_cluster1.cluster_name,
        "--region",
        var.region1
      ]
    }
  }
}

# Kubernetes and Helm provider for EKS Cluster 2
provider "kubernetes" {
  alias = "region2"

  host                   = module.eks_cluster2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster2.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks_cluster2.cluster_name,
      "--region",
      var.region2
    ]
  }
}

provider "helm" {
  alias = "region2"

  kubernetes {
    host                   = module.eks_cluster2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster2.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks_cluster2.cluster_name,
        "--region",
        var.region2
      ]
    }
  }
}

# IAM Policy for Calico CNI 
resource "aws_iam_policy" "additional_cluster1" {
  name   = "${var.cluster1_name}-calico-cni-additional"
  policy = file("${path.cwd}/min-iam-policy.json")
}

# IAM Policy for Calico CNI 
resource "aws_iam_policy" "additional_cluster2" {
  name   = "${var.cluster2_name}-calico-cni-additional"
  policy = file("${path.cwd}/min-iam-policy.json")
}

# Deploy Calico using Helm in EKS Cluster 1
resource "helm_release" "calico_cluster1" {
  provider         = helm.region1
  name             = "calico"
  chart            = "tigera-operator"
  repository       = "https://docs.projectcalico.org/charts"
  version          = var.calico_version
  namespace        = "tigera-operator"
  create_namespace = true

  values = [templatefile("${path.module}/helm_values/values-calico-cluster1.yaml", {
    pod_cidr     = var.pod_cidr1
    calico_encap = var.calico_encap
  })]

  depends_on = [
    module.eks_cluster1,
    null_resource.scale_up_node_group_cluster1
  ]
}

# Scale up node group for EKS Cluster 1
resource "null_resource" "scale_up_node_group_cluster1" {
  provisioner "local-exec" {
    command = "aws eks update-nodegroup-config --cluster-name ${split(":", module.eks_cluster1.eks_managed_node_groups.calico.node_group_id)[0]} --nodegroup-name ${split(":", module.eks_cluster1.eks_managed_node_groups.calico.node_group_id)[1]} --scaling-config desiredSize=${var.desired_size} --region ${var.region1}"
  }

  depends_on = [
    null_resource.remove_aws_node_ds_cluster1
  ]
}

# Remove AWS node daemonset for EKS Cluster 1
resource "null_resource" "remove_aws_node_ds_cluster1" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig_cluster1)
    }
    command = "kubectl delete ds -n kube-system aws-node --kubeconfig <(echo $KUBECONFIG | base64 -d)"
  }

  depends_on = [
    module.eks_cluster1
  ]
}

# Deploy Calico using Helm in EKS Cluster 2
resource "helm_release" "calico_cluster2" {
  provider         = helm.region2
  name             = "calico"
  chart            = "tigera-operator"
  repository       = "https://docs.projectcalico.org/charts"
  version          = var.calico_version
  namespace        = "tigera-operator"
  create_namespace = true

  values = [templatefile("${path.module}/helm_values/values-calico-cluster2.yaml", {
    pod_cidr     = var.pod_cidr2
    calico_encap = var.calico_encap
  })]

  depends_on = [
    module.eks_cluster2,
    null_resource.scale_up_node_group_cluster2
  ]
}

# Scale up node group for EKS Cluster 2
resource "null_resource" "scale_up_node_group_cluster2" {
  provisioner "local-exec" {
    command = "aws eks update-nodegroup-config --cluster-name ${split(":", module.eks_cluster2.eks_managed_node_groups.calico.node_group_id)[0]} --nodegroup-name ${split(":", module.eks_cluster2.eks_managed_node_groups.calico.node_group_id)[1]} --scaling-config desiredSize=${var.desired_size} --region ${var.region2}"
  }

  depends_on = [
    null_resource.remove_aws_node_ds_cluster2
  ]
}

# Remove AWS node daemonset for EKS Cluster 2
resource "null_resource" "remove_aws_node_ds_cluster2" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig_cluster2)
    }
    command = "kubectl delete ds -n kube-system aws-node --kubeconfig <(echo $KUBECONFIG | base64 -d)"
  }

  depends_on = [
    module.eks_cluster2
  ]
}
