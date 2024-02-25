provider "aws" {
  alias  = "region1"
  region = var.region1
}

provider "aws" {
  alias  = "region2"
  region = var.region2
}

data "aws_availability_zones" "available_region1" {
  provider = aws.region1
}

data "aws_availability_zones" "available_region2" {
  provider = aws.region2
}

locals {
  azs_region1 = data.aws_availability_zones.available_region1.names
  azs_region2 = data.aws_availability_zones.available_region2.names
}

# VPC 1 Configuration
module "vpc1" {
  source    = "terraform-aws-modules/vpc/aws"
  providers = { aws = aws.region1 }
  version   = ">= 5.0.0"

  name = "${var.name}-vpc1"
  cidr = var.vpc1_cidr
  azs  = local.azs_region1

  public_subnets  = [for idx in range(length(local.azs_region1)) : cidrsubnet(var.vpc1_cidr, 8, idx)]
  private_subnets = [for idx in range(length(local.azs_region1)) : cidrsubnet(var.vpc1_cidr, 8, idx + 4)]
}

# VPC 2 Configuration
module "vpc2" {
  source    = "terraform-aws-modules/vpc/aws"
  providers = { aws = aws.region2 }
  version   = ">= 5.0.0"

  name = "${var.name}-vpc2"
  cidr = var.vpc2_cidr
  azs  = local.azs_region2

  public_subnets  = [for idx in range(length(local.azs_region2)) : cidrsubnet(var.vpc2_cidr, 8, idx)]
  private_subnets = [for idx in range(length(local.azs_region2)) : cidrsubnet(var.vpc2_cidr, 8, idx + 4)]
}

# EKS Cluster 1 Configuration
module "eks_cluster1" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.10"
  providers       = { aws = aws.region1 }
  cluster_name    = var.cluster1_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc1.vpc_id
  subnet_ids      = slice(module.vpc1.private_subnets, 0, 2)

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    example = {
      desired_capacity = var.desired_size
      max_capacity     = 8
      min_capacity     = 0
      instance_type    = var.instance_type
      key_name         = var.ssh_keyname
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        additional               = aws_iam_policy.additional.arn
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
  }
}

# EKS Cluster 2 Configuration
module "eks_cluster2" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.10"
  providers       = { aws = aws.region2 }
  cluster_name    = var.cluster2_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc2.vpc_id
  subnet_ids      = slice(module.vpc2.private_subnets, 0, 2)

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    example = {
      desired_capacity = var.desired_size
      max_capacity     = 8
      min_capacity     = 0
      instance_type    = var.instance_type
      key_name         = var.ssh_keyname
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        additional               = aws_iam_policy.additional.arn
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

resource "aws_iam_policy" "additional" {
  name   = "${var.name}-calico-cni-additional"
  policy = file("${path.cwd}/min-iam-policy.json")
}
