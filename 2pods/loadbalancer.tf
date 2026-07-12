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

    type                    = "LoadBalancer"
    external_traffic_policy = "Cluster"
  }

  wait_for_load_balancer = true

  timeouts {
    create = "15m"
  }
}
