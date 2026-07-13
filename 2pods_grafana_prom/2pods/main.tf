terraform {
  required_version = ">= 1.6"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

variable "namespace" {
  description = "Namespace for the local autoscaling lab."
  type        = string
  default     = "web-autoscaling"
}

variable "image" {
  description = "Locally built CPU-intensive Go web image loaded into kind."
  type        = string
  default     = "local/web-autoscale:dev"
}

variable "prometheus_image" {
  description = "Pinned Prometheus image."
  type        = string
  default     = "prom/prometheus:v3.13.0"
}

variable "grafana_image" {
  description = "Pinned Grafana image."
  type        = string
  default     = "grafana/grafana:13.0.2"
}

variable "kube_state_metrics_image" {
  description = "Pinned kube-state-metrics image compatible with Kubernetes 1.35."
  type        = string
  default     = "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.19.0"
}

provider "kubernetes" {
  config_path = "${path.module}/.kubeconfig"
}

locals {
  labels = {
    app                            = "web"
    "app.kubernetes.io/name"       = "web"
    "app.kubernetes.io/part-of"    = "autoscaling-demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  web_source_hash = sha256(join("", [
    filesha256("${path.module}/app/main.go"),
    filesha256("${path.module}/app/go.mod"),
    filesha256("${path.module}/app/Dockerfile"),
  ]))
}

output "test_command" {
  value = "${path.module}/scripts/run-hpa-test.sh"
}

output "watch_hpa_command" {
  value = "KUBECONFIG=${path.module}/.kubeconfig kubectl -n ${var.namespace} get hpa web --watch"
}

output "grafana_url" {
  value = "http://127.0.0.1:3000/d/hpa-autoscaling/hpa-autoscaling-lab"
}
