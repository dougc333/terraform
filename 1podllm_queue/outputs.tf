output "namespace" {
  value = kubernetes_namespace_v1.lab.metadata[0].name
}

output "web_port_forward" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} port-forward service/web 8080:8080"
}

output "prometheus_port_forward" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} port-forward service/prometheus 9090:9090"
}

output "grafana_port_forward" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} port-forward service/grafana 3000:3000"
}
