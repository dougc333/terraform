output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = google_container_cluster.lab.name
}

output "cluster_zone" {
  value = google_container_cluster.lab.location
}

output "node_machine_type" {
  value = var.machine_type
}

output "web_image" {
  value = local.web_image
}

output "namespace" {
  value = kubernetes_namespace_v1.lab.metadata[0].name
}

output "web_port_forward" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} port-forward service/web 8080:8080"
}

output "prometheus_port_forward" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} port-forward service/prometheus 9090:9090"
}
