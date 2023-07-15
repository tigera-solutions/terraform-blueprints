output "configure_kubectl" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.spoke_1_aks.name} --resource-group ${azurerm_kubernetes_cluster.spoke_1_aks.resource_group_name} --context ${azurerm_kubernetes_cluster.spoke_1_aks.name}"
}

output "cluster_host" {
  value     = azurerm_kubernetes_cluster.spoke_1_aks.kube_config.0.host
  sensitive = true
}

output "cluster_client_key" {
  value     = azurerm_kubernetes_cluster.spoke_1_aks.kube_config.0.client_key
  sensitive = true
}

output "cluster_client_certificate" {
  value     = azurerm_kubernetes_cluster.spoke_1_aks.kube_config.0.client_certificate
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.spoke_1_aks.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "cluster_kube_config" {
  value     = azurerm_kubernetes_cluster.spoke_1_aks.kube_config_raw
  sensitive = true
}
