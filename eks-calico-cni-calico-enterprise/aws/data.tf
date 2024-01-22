data "local_sensitive_file" "calico_enterprise_pull_secret" {
  filename = "${var.calico_enterprise_pull_secret_path}"
}

data "local_sensitive_file" "calico_enterprise_manager_sslcert" {
  filename = "${var.calico_enterprise_manager_sslcert_path}"
}

data "local_sensitive_file" "calico_enterprise_manager_sslkey" {
  filename = "${var.calico_enterprise_manager_sslkey_path}"
}
