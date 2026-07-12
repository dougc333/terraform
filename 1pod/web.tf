locals {
  web_labels = {
    "app.kubernetes.io/name"       = "web"
    "app.kubernetes.io/component"  = "server"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  web_source_hash = sha256(join("", [
    filesha256("${path.module}/app/main.go"),
    filesha256("${path.module}/app/go.mod"),
    filesha256("${path.module}/app/Dockerfile"),
  ]))
}

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.web_labels
  }

  wait_for_rollout = true

  spec {
    replicas               = 1
    revision_history_limit = 3

    selector {
      match_labels = local.web_labels
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.web_labels

        annotations = {
          "lab.example.com/source-hash" = local.web_source_hash
        }
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 15

        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "web"
          image             = var.web_image
          image_pull_policy = "Never"

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true

            capabilities {
              drop = ["ALL"]
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
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds  = 3
            timeout_seconds = 1
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
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.web_labels
  }

  spec {
    selector = local.web_labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8080
      target_port = "http"
    }

    type = "ClusterIP"
  }
}
