locals {
  prometheus_labels = {
    "app.kubernetes.io/name"       = "prometheus"
    "app.kubernetes.io/component"  = "monitoring"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_config_map_v1" "prometheus" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-YAML
      global:
        scrape_interval: 2s
        evaluation_interval: 2s

      scrape_configs:
        - job_name: web
          metrics_path: /metrics
          static_configs:
            - targets:
                - web.${var.namespace}.svc.cluster.local:8080
              labels:
                application: web
    YAML
  }
}

resource "kubernetes_deployment_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.prometheus_labels
  }

  wait_for_rollout = true

  spec {
    replicas = 1

    selector {
      match_labels = local.prometheus_labels
    }

    template {
      metadata {
        labels = local.prometheus_labels
      }

      spec {
        automount_service_account_token = false

        container {
          name  = "prometheus"
          image = var.prometheus_image

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=2h",
          ]

          port {
            name           = "http"
            container_port = 9090
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path   = "/-/ready"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds  = 3
            timeout_seconds = 2
          }

          liveness_probe {
            http_get {
              path   = "/-/healthy"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 10
            timeout_seconds   = 2
            failure_threshold = 3
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/prometheus"
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map_v1.prometheus.metadata[0].name
          }
        }

        volume {
          name = "data"

          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.prometheus_labels
  }

  spec {
    selector = local.prometheus_labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 9090
      target_port = "http"
    }

    type = "ClusterIP"
  }
}

