locals {
  kube_state_metrics_labels = {
    "app.kubernetes.io/name"       = "kube-state-metrics"
    "app.kubernetes.io/component"  = "metrics"
    "app.kubernetes.io/part-of"    = "autoscaling-demo"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_service_account_v1" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "kube_state_metrics" {
  metadata {
    name = "two-pod-lab-kube-state-metrics"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "kube_state_metrics" {
  metadata {
    name = "two-pod-lab-kube-state-metrics"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kube_state_metrics.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kube_state_metrics.metadata[0].name
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
    labels    = local.kube_state_metrics_labels
  }

  wait_for_rollout = true

  spec {
    replicas = 1

    selector {
      match_labels = local.kube_state_metrics_labels
    }

    template {
      metadata {
        labels = local.kube_state_metrics_labels
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kube_state_metrics.metadata[0].name

        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "kube-state-metrics"
          image = var.kube_state_metrics_image

          args = [
            "--resources=pods,deployments,horizontalpodautoscalers",
          ]

          port {
            name           = "metrics"
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }

            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            tcp_socket {
              port = "metrics"
            }

            period_seconds  = 5
            timeout_seconds = 2
          }

          liveness_probe {
            tcp_socket {
              port = "metrics"
            }

            period_seconds    = 10
            timeout_seconds   = 2
            failure_threshold = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
    labels    = local.kube_state_metrics_labels
  }

  spec {
    selector = local.kube_state_metrics_labels

    port {
      name        = "metrics"
      port        = 8080
      target_port = "metrics"
    }

    type = "ClusterIP"
  }
}
