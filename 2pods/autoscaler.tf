resource "kubernetes_horizontal_pod_autoscaler_v2" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  spec {
    min_replicas = 1
    max_replicas = 2

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.web.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy                 = "Max"

        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }

      # Avoid scaling down because of a brief drop in traffic.
      scale_down {
        stabilization_window_seconds = 300
        select_policy                 = "Max"

        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }
    }
  }
}
