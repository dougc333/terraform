resource "kubernetes_namespace_v1" "web" {
  metadata {
    name = var.namespace

    labels = {
      # The demo image supports baseline policy. A production-owned
      # image should normally comply with the restricted policy.
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}
