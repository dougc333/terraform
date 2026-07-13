provider "kubernetes" {
  config_path    = "${path.module}/.kubeconfig"
  config_context = "kind-${var.cluster_name}"
}

