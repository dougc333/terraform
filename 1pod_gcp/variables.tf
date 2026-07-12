variable "project_id" {
  description = "Google Cloud project ID. Set with TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the network and Artifact Registry."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the low-cost zonal GKE cluster."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Name of the zonal GKE cluster."
  type        = string
  default     = "one-pod-gcp-lab"
}

variable "machine_type" {
  description = "GKE node VM type. e2-micro is the smallest E2 shared-core type."
  type        = string
  default     = "e2-micro"
}

variable "namespace" {
  description = "Namespace for the web server and Prometheus."
  type        = string
  default     = "web-observability"
}

variable "artifact_repository" {
  description = "Artifact Registry repository used for the web image."
  type        = string
  default     = "one-pod-lab"
}

variable "web_image_name" {
  description = "Name of the web image in Artifact Registry."
  type        = string
  default     = "web-metrics"
}

variable "web_image_tag" {
  description = "Tag of the web image deployed to GKE."
  type        = string
  default     = "dev"
}

variable "prometheus_image" {
  description = "Pinned Prometheus image."
  type        = string
  default     = "prom/prometheus:v3.13.0"
}
