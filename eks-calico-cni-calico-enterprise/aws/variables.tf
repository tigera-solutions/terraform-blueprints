variable "name" {
  description = "Name of cluster"
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

variable "calico_encap" {
  description = "Calico network overlay type"
  type        = string
  default     = "VXLAN"
}

variable "calico_network_bgp" {
  description = "Calico network BGP"
  type        = string
  default     = "Disabled"
}

variable "cluster_version" {
  description = "Kubernetes version for this cluster"
  type        = string
  default     = "1.26"
}

variable "calico_enterprise_helm_chart" {
  description = "Calico Enterprise Helm Chart"
  type        = string
  default     = "https://downloads.tigera.io/ee/charts/tigera-operator-v3.18.0-2.0-0.tgz"
}

variable "desired_size" {
  description = "Number of cluster nodes"
  type        = string
  default     = "4"
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

variable "create_enterprise_manager_sslcerts" {
  description = "Determines whether to create tigera-manager ssl certificates"
  type        = bool
  default     = false
}

variable "calico_enterprise_pull_secret_path" {
  description = "Path to a local file that contains Calico Enterprise pull secret"
  type        = string
  default     = "/Users/Shared/docker_cfg.json"
}

variable "calico_enterprise_manager_sslcert_path" {
  description = "Path to a local file that represents Calico Enterprise manager SSL cert (file can be empty but has to exist)"
  type        = string
  default     = "/Users/Shared/STAR_tigera-solutions_io.crt"
}

variable "calico_enterprise_manager_sslkey_path" {
  description = "Path to a local file that represents Calico Enterprise manager SSL cert key (file can be empty but has to exist)"
  type        = string
  default     = "/Users/Shared/STAR_tigera-solutions_io.key"
}
