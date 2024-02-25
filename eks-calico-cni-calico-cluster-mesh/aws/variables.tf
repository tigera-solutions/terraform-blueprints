variable "name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = "demo"
}

variable "region" {
  description = "AWS Region of cluster"
  type        = string
  default     = "us-east-1"
}

variable "ssh_keyname" {
  description = "AWS SSH Keypair Name"
  type        = string
  default     = "sabo"
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "AWS Secondary VPC CIDR"
  type        = string
  default     = "10.99.0.0/16"
}

variable "pod_cidr" {
  description = "Calico POD CIDR"
  type        = string
  default     = "10.244.0.0/24"
}

variable "cluster_service_ipv4_cidr" {
  description = "Kubernetes Service CIDR"
  type        = string
  default     = "10.9.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for this cluster"
  type        = string
  default     = "1.27"
}

variable "calico_version" {
  description = "Calico Open Source release version"
  type        = string
  default     = "3.25.1"
}

variable "desired_size" {
  description = "Number of cluster nodes"
  type        = string
  default     = "2"
}

variable "instance_type" {
  description = "Cluster node AWS EC2 instance type"
  type        = string
  default     = "m5.2xlarge"
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group. Valid values are AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64"
  type        = string
  default     = "AL2_x86_64"
}
