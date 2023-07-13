data "local_sensitive_file" "calico_enterprise_pull_secret" {
  filename = "/Users/sabo/.docker/quay.json"
}

data "local_sensitive_file" "calico_enterprise_license" {
  filename = "/Users/sabo/Source/demo/license.yaml"
}
