output "resource_group_name" {
  description = "Azure resource group containing the lab."
  value       = azurerm_resource_group.lab.name
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.lab.name
}

output "node_vm_size" {
  description = "VM size used by the single AKS node."
  value       = var.node_vm_size
}

output "namespace" {
  description = "Kubernetes namespace containing the Hello World server."
  value       = kubernetes_namespace_v1.lab.metadata[0].name
}

output "hello_world_public_ip" {
  description = "Public IP assigned to the Hello World LoadBalancer Service."
  value       = try(kubernetes_service_v1.hello.status[0].load_balancer[0].ingress[0].ip, null)
}

output "hello_world_url" {
  description = "Public URL of the Hello World server."
  value       = try("http://${kubernetes_service_v1.hello.status[0].load_balancer[0].ingress[0].ip}", null)
}

output "ping_url" {
  description = "Public HTTP endpoint that returns pong when the server is reachable."
  value       = try("http://${kubernetes_service_v1.hello.status[0].load_balancer[0].ingress[0].ip}/ping", null)
}

output "get_credentials_command" {
  description = "Command that writes an isolated kubeconfig for this lab."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.lab.name} --name ${azurerm_kubernetes_cluster.lab.name} --file ${path.module}/.kubeconfig --overwrite-existing"
}
