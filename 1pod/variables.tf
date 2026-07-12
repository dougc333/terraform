variable "cluster_name" {
  description = "Name of the local kind cluster."
  type        = string
  default     = "one-pod-lab"
}

variable "namespace" {
  description = "Namespace for the web server and Prometheus."
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

