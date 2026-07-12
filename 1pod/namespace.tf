resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of"          = "one-pod-observability-lab"
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

