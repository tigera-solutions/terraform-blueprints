output "aks_creds" {
  value = "az aks get-credentials --name ${var.cluster_name}  --resource-group ${var.vnet_resource_group_name} --context ${var.cluster_name}"
}
