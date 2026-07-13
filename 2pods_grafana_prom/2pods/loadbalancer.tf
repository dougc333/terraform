resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "http"
    }

    # The k6 Job runs inside kind and reaches this virtual IP. kube-proxy
    # distributes new connections across every Ready web Pod endpoint.
    type = "ClusterIP"
  }
}
