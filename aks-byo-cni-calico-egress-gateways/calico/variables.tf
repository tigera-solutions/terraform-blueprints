variable "pod_cidr" {
  description = "Calico POD CIDR"
  type        = string
  default     = "10.244.0.0/24"
}

variable "calico_version" {
  description = "Calico Open Source release version"
  type        = string
  default     = "3.25.1"
}
