resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
    labels    = local.labels
  }

  wait_for_rollout = true

  spec {
    # Initial number of web servers.
    replicas               = 1
    revision_history_limit = 5
    min_ready_seconds      = 5

    selector {
      match_labels = local.labels
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        # Start the replacement before stopping the existing Pod.
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.labels

        annotations = {
          "lab.example.com/source-hash" = local.web_source_hash
        }
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 30

        container {
          name              = "web"
          image             = var.image
          image_pull_policy = "Never"

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          # HPA calculates CPU utilization relative to this request.
          resources {
            requests = {
              cpu    = "200m"
              memory = "32Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }

          startup_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            failure_threshold = 30
            period_seconds    = 1
            timeout_seconds   = 1
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 3
            timeout_seconds   = 1
            failure_threshold = 3
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 10
            timeout_seconds   = 1
            failure_threshold = 3
          }
        }
      }
    }
  }

  lifecycle {
    # The HPA owns replicas after initial creation.
    # Without this, Terraform could try to change 2 replicas back to 1.
    ignore_changes = [
      spec[0].replicas
    ]
  }
}
