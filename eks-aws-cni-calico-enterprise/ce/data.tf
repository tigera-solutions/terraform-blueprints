data "local_sensitive_file" "calico_enterprise_pull_secret" {
  filename = "${var.calico_enterprise_pull_secret_path}"
}
