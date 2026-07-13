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
          type = "Utilization"
          # With a 200m request, this target asks HPA to keep average web CPU
          # near 100m per Pod. The 500m limit leaves room for scale-up signals.
          average_utilization = 50
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy                = "Max"

        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 30
        }
      }

      # Production commonly uses a longer window. Sixty seconds keeps this
      # local demonstration repeatable without a five-minute idle wait.
      scale_down {
        stabilization_window_seconds = 60
        select_policy                = "Max"

        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 30
        }
      }
    }
  }
}
