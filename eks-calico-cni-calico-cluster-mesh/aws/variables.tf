variable "region1" {
  description = "AWS region for the first VPC and EKS cluster"
}

variable "region2" {
  description = "AWS region for the second VPC and EKS cluster"
}

variable "vpc1_cidr" {
  description = "CIDR block for the first VPC"
}

variable "vpc2_cidr" {
  description = "CIDR block for the second VPC"
}

variable "cluster1_name" {
  description = "The name of the first EKS cluster"
}

variable "cluster2_name" {
  description = "The name of the second EKS cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS clusters"
}

variable "instance_type" {
  description = "Instance type for EKS worker nodes"
}

variable "desired_size" {
  description = "Desired number of nodes in the EKS clusters"
}

variable "ssh_keyname" {
  description = "SSH key name for access to worker nodes"
}

variable "pod_cidr1" {
  description = "Pod CIDR for the first EKS cluster"
}

variable "pod_cidr2" {
  description = "Pod CIDR for the second EKS cluster"
}

variable "calico_version" {
  description = "Calico version for networking in the clusters"
}

variable "calico_encap" {
  description = "Encapsulation method for Calico"
  default     = "VXLAN"
}
