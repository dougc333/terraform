terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Google Cloud project ID"
}

variable "region" {
  type        = string
  description = "GKE cluster region"
  default     = "us-central1"
}

variable "cluster_name" {
  type        = string
  description = "Existing GKE cluster name"
}

variable "namespace" {
  type        = string
  default     = "production-web"
}

variable "image" {
  type        = string
  description = "Web application image"

  # This image intentionally consumes CPU per request,
  # making HPA behavior easy to demonstrate.
  default = "registry.k8s.io/hpa-example:latest"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.region
}

provider "kubernetes" {
  host = "https://${data.google_container_cluster.cluster.endpoint}"

  token = data.google_client_config.current.access_token

  cluster_ca_certificate = base64decode(
    data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  )
}

locals {
  labels = {
    app                          = "web"
    "app.kubernetes.io/name"     = "web"
    "app.kubernetes.io/part-of"  = "autoscaling-demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
