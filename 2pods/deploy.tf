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
    min_ready_seconds      = 10

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
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 30

        # Prefer placing the second replica in a different zone.
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                topology_key = "topology.kubernetes.io/zone"

                label_selector {
                  match_labels = local.labels
                }
              }
            }
          }
        }

        container {
          name              = "web"
          image             = var.image
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          # HPA calculates CPU utilization relative to this request.
          resources {
            requests = {
              cpu    = "200m"
              memory = "64Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }

          startup_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }

            failure_threshold = 30
            period_seconds    = 2
            timeout_seconds   = 1
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 5
            timeout_seconds   = 2
            failure_threshold = 3
            success_threshold = 1
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 10
            timeout_seconds   = 2
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
