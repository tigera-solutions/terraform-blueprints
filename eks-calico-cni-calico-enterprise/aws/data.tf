data "local_sensitive_file" "calico_enterprise_pull_secret" {
  filename = "${var.calico_enterprise_pull_secret_path}"
}

data "local_sensitive_file" "calico_enterprise_manager_sslcert" {
  count = local.create_enterprise_manager_sslcerts ? 1 : 0

  filename = "${var.calico_enterprise_manager_sslcert_path}"
}

data "local_sensitive_file" "calico_enterprise_manager_sslkey" {
  count = local.create_enterprise_manager_sslcerts ? 1 : 0

  filename = "${var.calico_enterprise_manager_sslkey_path}"
}
