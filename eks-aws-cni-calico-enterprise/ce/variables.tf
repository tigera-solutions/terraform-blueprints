variable "calico_enterprise_version" {
  description = "Calico Enterprise release version"
  type        = string
  default     = "3.17.1-0"
}

variable "calico_enterprise_pull_secret_path" {
  description = "Path to a local file that contains Calico Enterprise pull secret"
  type        = string
  default     = "/Users/Shared/docker_cfg.json"
}
