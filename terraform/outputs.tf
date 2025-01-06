
output "resource_group_name" {
  value = data.azurerm_resource_group.default.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.app-cluster.name
}

output "kubectl_command" {
  value = "az aks get-credentials --resource-group ${data.azurerm_resource_group.default.name} --name ${azurerm_kubernetes_cluster.app-cluster.name} --overwrite-existing"
}