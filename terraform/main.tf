
# import resource group
data "azurerm_resource_group" "default" {
  name = "devops-dojo"
}

# create a new kubernetes cluster
resource "azurerm_kubernetes_cluster" "app-cluster" {
  name                = "app-cluster"
  location            = data.azurerm_resource_group.default.location
  resource_group_name = data.azurerm_resource_group.default.name
  dns_prefix          = "app-k8s"
  kubernetes_version  = "1.30.6"

  default_node_pool {
    name            = "app"
    node_count      = 2
    vm_size         = "Standard_DS2_v2"
    os_disk_size_gb = 50
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true

  tags = {
    environment = "DevOps Dojo"
  }
}

# assign the cluster contributor role to the cluster identity
resource "azurerm_role_assignment" "aks_contributor" {
  principal_id         = azurerm_kubernetes_cluster.app-cluster.identity[0].principal_id
  scope                = data.azurerm_resource_group.default.id
  role_definition_name = "Contributor"
}

# create a local kubeconfig file for ansible
resource "local_file" "kubeconfig" {
  content  = azurerm_kubernetes_cluster.app-cluster.kube_config_raw
  filename = "../ansible/kubeconfig"

  provisioner "local-exec" {
    command = "chmod 600 ../ansible/kubeconfig"
  }
}

# dynamically create an inventory file for ansible
resource "local_file" "inventory" {
  content = <<EOT
[localhost]
127.0.0.1 ansible_connection=local ansible_python_interpreter=/Library/Frameworks/Python.framework/Versions/3.12/bin/python3

[aks]
aks-cluster ansible_connection=local

[all:vars]
kubernetes_cluster_name=${azurerm_kubernetes_cluster.app-cluster.name}
kubernetes_resource_group=${data.azurerm_resource_group.default.name}
kubeconfig_path=../ansible/kubeconfig
EOT

  filename = "../ansible/inventory/hosts.ini"
}

# trigger the vm configuration with ansible
resource "null_resource" "ansible_provisioner" {
  depends_on = [
    local_file.inventory,
    local_file.kubeconfig,
    azurerm_kubernetes_cluster.app-cluster
  ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 60 # wait for cluster to be ready
      KUBECONFIG=../ansible/kubeconfig \
      ansible-playbook \
        -i ../ansible/inventory/hosts.ini \
        ../ansible/playbook.yml \
        -e "kubernetes_cluster_name=${azurerm_kubernetes_cluster.app-cluster.name}" \
        -e "kubernetes_resource_group=${data.azurerm_resource_group.default.name}"
    EOT

    working_dir = "../ansible"
  }
}

# retreive existing dns record for the server from azure
data "azurerm_dns_zone" "domain" {
  name                = var.domain_name
  resource_group_name = data.azurerm_resource_group.default.name
}