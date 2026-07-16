locals {
  hello_labels = {
    "app.kubernetes.io/name"       = "hello-world"
    "app.kubernetes.io/component"  = "server"
    "app.kubernetes.io/part-of"    = "one-pod-azure-lab"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of" = "one-pod-azure-lab"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.lab]
}

resource "kubernetes_config_map_v1" "hello" {
  metadata {
    name      = "hello-world-content"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  data = {
    "index.html" = <<-HTML
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>One-Pod Azure Lab</title>
          <style>
            body { font-family: system-ui, sans-serif; margin: 4rem; color: #172554; }
            main { max-width: 48rem; margin: auto; }
            code { background: #dbeafe; padding: .2rem .4rem; }
          </style>
        </head>
        <body>
          <main>
            <h1>Hello from Azure Kubernetes Service!</h1>
            <p>This response is served by exactly one Kubernetes Pod.</p>
            <p>Project: <code>1pod_azure</code></p>
          </main>
        </body>
      </html>
    HTML
  }
}

resource "kubernetes_config_map_v1" "nginx" {
  metadata {
    name      = "hello-world-nginx"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  data = {
    "default.conf" = <<-NGINX
      server {
        listen 80;
        server_name _;

        location = /ping {
          default_type text/plain;
          return 200 "pong\n";
        }

        location = /healthz {
          access_log off;
          default_type text/plain;
          return 200 "ok\n";
        }

        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
      }
    NGINX
  }
}

resource "kubernetes_deployment_v1" "hello" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.hello_labels
  }

  wait_for_rollout = true

  spec {
    replicas               = 1
    revision_history_limit = 2

    selector {
      match_labels = local.hello_labels
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
        labels = local.hello_labels

        annotations = {
          "lab.example.com/content-hash" = sha256(join("", [
            kubernetes_config_map_v1.hello.data["index.html"],
            kubernetes_config_map_v1.nginx.data["default.conf"],
          ]))
        }
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 10

        container {
          name              = "hello-world"
          image             = var.nginx_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }

            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          startup_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            failure_threshold = 30
            period_seconds    = 2
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds  = 5
            timeout_seconds = 2
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "http"
              scheme = "HTTP"
            }

            period_seconds    = 10
            timeout_seconds   = 2
            failure_threshold = 3
          }

          volume_mount {
            name       = "content"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
            read_only  = true
          }
        }

        volume {
          name = "content"

          config_map {
            name = kubernetes_config_map_v1.hello.metadata[0].name
          }
        }

        volume {
          name = "nginx-config"

          config_map {
            name = kubernetes_config_map_v1.nginx.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "hello" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.hello_labels
  }

  wait_for_load_balancer = true

  spec {
    selector = local.hello_labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "http"
    }

    type = "LoadBalancer"
  }
}
