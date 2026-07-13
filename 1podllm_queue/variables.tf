variable "cluster_name" {
  description = "Name of the local kind cluster."
  type        = string
  default     = "one-pod-lab"
}

variable "namespace" {
  description = "Namespace for the web server, Prometheus, and Grafana."
  type        = string
  default     = "web-observability"
}

variable "web_image" {
  description = "Locally built web image loaded into kind."
  type        = string
  default     = "local/web-metrics:dev"
}

variable "prometheus_image" {
  description = "Pinned Prometheus image."
  type        = string
  default     = "prom/prometheus:v3.13.0"
}

variable "grafana_image" {
  description = "Pinned Grafana OSS image."
  type        = string
  default     = "grafana/grafana:12.4.0"
}
