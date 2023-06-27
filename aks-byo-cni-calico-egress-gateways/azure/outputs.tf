output "configure_kubectl" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.spoke_1_aks.name} --resource-group ${azurerm_kubernetes_cluster.spoke_1_aks.resource_group_name}"
}
