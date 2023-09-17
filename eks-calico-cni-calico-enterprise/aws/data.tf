data "local_sensitive_file" "calico_enterprise_pull_secret" {
  filename = "/Users/sabo/.docker/quay.json"
}

data "local_sensitive_file" "calico_enterprise_manager_sslcert" {
  filename = "/Users/sabo/Source/demo/STAR_tigera-solutions_io.crt"
}

data "local_sensitive_file" "calico_enterprise_manager_sslkey" {
  filename = "/Users/sabo/Source/demo/STAR_tigera-solutions_io.key"
}
