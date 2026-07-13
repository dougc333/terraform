locals {
  prometheus_labels = {
    "app.kubernetes.io/name"       = "prometheus"
    "app.kubernetes.io/component"  = "monitoring"
    "app.kubernetes.io/part-of"    = "autoscaling-demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_service_account_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }
}

resource "kubernetes_role_v1" "prometheus_discovery" {
  metadata {
    name      = "prometheus-pod-discovery"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "prometheus_discovery" {
  metadata {
    name      = "prometheus-pod-discovery"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.prometheus_discovery.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prometheus.metadata[0].name
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "prometheus" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-YAML
      global:
        scrape_interval: 5s
        evaluation_interval: 5s

      scrape_configs:
        - job_name: prometheus
          static_configs:
            - targets: ["127.0.0.1:9090"]

        - job_name: web
          metrics_path: /metrics
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names: ["${var.namespace}"]
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
              action: keep
              regex: web
            - source_labels: [__meta_kubernetes_pod_phase]
              action: keep
              regex: Running
            - source_labels: [__meta_kubernetes_pod_container_port_name]
              action: keep
              regex: http
            - source_labels: [__meta_kubernetes_namespace]
              target_label: namespace
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod

        - job_name: kube-state-metrics
          static_configs:
            - targets:
                - kube-state-metrics.${var.namespace}.svc.cluster.local:8080
    YAML
  }
}

resource "kubernetes_deployment_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
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

        annotations = {
          "lab.example.com/config-hash" = sha256(kubernetes_config_map_v1.prometheus.data["prometheus.yml"])
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.prometheus.metadata[0].name

        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          run_as_group    = 65534
          fs_group        = 65534

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "prometheus"
          image = var.prometheus_image

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=6h",
            "--web.enable-remote-write-receiver",
          ]

          port {
            name           = "http"
            container_port = 9090
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
              path = "/-/ready"
              port = "http"
            }

            period_seconds  = 3
            timeout_seconds = 2
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "http"
            }

            period_seconds    = 10
            timeout_seconds   = 2
            failure_threshold = 3
          }

          security_context {
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
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
    namespace = kubernetes_namespace_v1.web.metadata[0].name
    labels    = local.prometheus_labels
  }

  spec {
    selector = local.prometheus_labels

    port {
      name        = "http"
      port        = 9090
      target_port = "http"
    }

    type = "ClusterIP"
  }
}
