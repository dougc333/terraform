locals {
  grafana_labels = {
    "app.kubernetes.io/name"       = "grafana"
    "app.kubernetes.io/component"  = "visualization"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_config_map_v1" "grafana_provisioning" {
  metadata {
    name      = "grafana-provisioning"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  data = {
    "datasources.yaml" = <<-YAML
      apiVersion: 1

      datasources:
        - name: Prometheus
          uid: prometheus
          type: prometheus
          access: proxy
          url: http://prometheus.${var.namespace}.svc.cluster.local:9090
          isDefault: true
          editable: false
          jsonData:
            timeInterval: 2s
    YAML

    "dashboards.yaml" = <<-YAML
      apiVersion: 1

      providers:
        - name: one-pod-lab
          orgId: 1
          folder: Lab
          folderUid: one-pod-lab
          type: file
          disableDeletion: true
          editable: false
          updateIntervalSeconds: 10
          options:
            path: /var/lib/grafana/dashboards
    YAML
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard" {
  metadata {
    name      = "grafana-dashboard"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  data = {
    "one-pod-dashboard.json" = jsonencode({
      annotations = {
        list = []
      }
      editable             = false
      fiscalYearStartMonth = 0
      graphTooltip         = 1
      links                = []
      liveNow              = false
      panels = [
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "palette-classic"
              }
              custom = {
                axisCenteredZero = false
                axisColorMode    = "text"
                axisLabel        = ""
                axisPlacement    = "auto"
                barAlignment     = 0
                drawStyle        = "line"
                fillOpacity      = 18
                gradientMode     = "opacity"
                hideFrom = {
                  legend  = false
                  tooltip = false
                  viz     = false
                }
                lineInterpolation = "smooth"
                lineWidth         = 2
                pointSize         = 5
                scaleDistribution = {
                  type = "linear"
                }
                showPoints = "never"
                spanNulls  = false
                stacking = {
                  group = "A"
                  mode  = "none"
                }
                thresholdsStyle = {
                  mode = "off"
                }
              }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "green"
                    value = null
                  },
                  {
                    color = "red"
                    value = 80
                  }
                ]
              }
              unit = "reqps"
            }
            overrides = []
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 0
          }
          id = 1
          options = {
            legend = {
              calcs       = ["mean", "max"]
              displayMode = "table"
              placement   = "bottom"
              showLegend  = true
            }
            tooltip = {
              mode = "single"
              sort = "none"
            }
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode   = "code"
              expr         = "rate(web_requests_total[1m])"
              legendFormat = "requests/sec"
              range        = true
              refId        = "A"
            }
          ]
          title = "Request rate"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-GrYlRd"
              }
              custom = {
                axisCenteredZero = false
                axisColorMode    = "text"
                axisLabel        = ""
                axisPlacement    = "auto"
                barAlignment     = 0
                drawStyle        = "line"
                fillOpacity      = 20
                gradientMode     = "opacity"
                hideFrom = {
                  legend  = false
                  tooltip = false
                  viz     = false
                }
                lineInterpolation = "smooth"
                lineWidth         = 2
                pointSize         = 5
                scaleDistribution = {
                  type = "linear"
                }
                showPoints = "never"
                spanNulls  = false
                stacking = {
                  group = "A"
                  mode  = "none"
                }
                thresholdsStyle = {
                  mode = "line"
                }
              }
              mappings = []
              min      = 0
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "green"
                    value = null
                  },
                  {
                    color = "yellow"
                    value = 60
                  },
                  {
                    color = "red"
                    value = 85
                  }
                ]
              }
              unit = "percent"
            }
            overrides = []
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 0
          }
          id = 2
          options = {
            legend = {
              calcs       = ["mean", "max"]
              displayMode = "table"
              placement   = "bottom"
              showLegend  = true
            }
            tooltip = {
              mode = "single"
              sort = "none"
            }
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode   = "code"
              expr         = "rate(process_cpu_seconds_total{job=\"web\"}[1m]) * 100"
              legendFormat = "web process CPU"
              range        = true
              refId        = "A"
            }
          ]
          title = "Web process CPU"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds"
              }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "blue"
                    value = null
                  }
                ]
              }
              unit = "short"
            }
            overrides = []
          }
          gridPos = {
            h = 6
            w = 6
            x = 0
            y = 8
          }
          id = 3
          options = {
            colorMode   = "value"
            graphMode   = "area"
            justifyMode = "auto"
            orientation = "auto"
            reduceOptions = {
              calcs  = ["lastNotNull"]
              fields = ""
              values = false
            }
            showPercentChange = true
            textMode          = "auto"
            wideLayout        = true
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode = "code"
              expr       = "increase(web_requests_total[1m])"
              range      = true
              refId      = "A"
            }
          ]
          title = "Requests in last minute"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds"
              }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "green"
                    value = null
                  },
                  {
                    color = "yellow"
                    value = 0.5
                  },
                  {
                    color = "red"
                    value = 1
                  }
                ]
              }
              unit = "s"
            }
            overrides = []
          }
          gridPos = {
            h = 6
            w = 6
            x = 6
            y = 8
          }
          id = 4
          options = {
            colorMode   = "value"
            graphMode   = "area"
            justifyMode = "auto"
            orientation = "auto"
            reduceOptions = {
              calcs  = ["lastNotNull"]
              fields = ""
              values = false
            }
            showPercentChange = false
            textMode          = "auto"
            wideLayout        = true
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode = "code"
              expr       = "rate(web_request_duration_seconds_sum[1m]) / rate(web_request_duration_seconds_count[1m])"
              range      = true
              refId      = "A"
            }
          ]
          title = "Average request duration"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds"
              }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "green"
                    value = null
                  },
                  {
                    color = "yellow"
                    value = 15
                  },
                  {
                    color = "red"
                    value = 30
                  }
                ]
              }
              unit = "short"
            }
            overrides = []
          }
          gridPos = {
            h = 6
            w = 6
            x = 12
            y = 8
          }
          id = 5
          options = {
            colorMode   = "value"
            graphMode   = "area"
            justifyMode = "auto"
            orientation = "auto"
            reduceOptions = {
              calcs  = ["lastNotNull"]
              fields = ""
              values = false
            }
            showPercentChange = false
            textMode          = "auto"
            wideLayout        = true
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode = "code"
              expr       = "web_requests_in_flight"
              range      = true
              refId      = "A"
            }
          ]
          title = "Requests in flight"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = "prometheus"
          }
          fieldConfig = {
            defaults = {
              color = {
                mode = "thresholds"
              }
              mappings = []
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "green"
                    value = null
                  },
                  {
                    color = "yellow"
                    value = 100000000
                  },
                  {
                    color = "red"
                    value = 120000000
                  }
                ]
              }
              unit = "bytes"
            }
            overrides = []
          }
          gridPos = {
            h = 6
            w = 6
            x = 18
            y = 8
          }
          id = 6
          options = {
            colorMode   = "value"
            graphMode   = "area"
            justifyMode = "auto"
            orientation = "auto"
            reduceOptions = {
              calcs  = ["lastNotNull"]
              fields = ""
              values = false
            }
            showPercentChange = false
            textMode          = "auto"
            wideLayout        = true
          }
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "prometheus"
              }
              editorMode = "code"
              expr       = "process_resident_memory_bytes{job=\"web\"}"
              range      = true
              refId      = "A"
            }
          ]
          title = "Web process memory"
          type  = "stat"
        }
      ]
      refresh       = "5s"
      schemaVersion = 41
      tags          = ["one-pod-lab", "prometheus"]
      templating = {
        list = []
      }
      time = {
        from = "now-15m"
        to   = "now"
      }
      timepicker = {}
      timezone   = "browser"
      title      = "One-Pod Observability"
      uid        = "one-pod-overview"
      version    = 1
      weekStart  = ""
    })
  }
}

resource "kubernetes_deployment_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.grafana_labels
  }

  wait_for_rollout = true

  spec {
    replicas = 1

    selector {
      match_labels = local.grafana_labels
    }

    template {
      metadata {
        labels = local.grafana_labels

        annotations = {
          "lab.example.com/dashboard-hash" = sha256(kubernetes_config_map_v1.grafana_dashboard.data["one-pod-dashboard.json"])
        }
      }

      spec {
        automount_service_account_token  = false
        termination_grace_period_seconds = 15

        security_context {
          run_as_non_root = true
          run_as_user     = 472
          run_as_group    = 472
          fs_group        = 472

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "grafana"
          image = var.grafana_image

          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Viewer"
          }

          env {
            name  = "GF_AUTH_DISABLE_LOGIN_FORM"
            value = "true"
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          env {
            name  = "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH"
            value = "/var/lib/grafana/dashboards/one-pod-dashboard.json"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 472
            run_as_group               = 472

            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            http_get {
              path   = "/api/health"
              port   = "http"
              scheme = "HTTP"
            }

            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 2
          }

          liveness_probe {
            http_get {
              path   = "/api/health"
              port   = "http"
              scheme = "HTTP"
            }

            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
            read_only  = true
          }

          volume_mount {
            name       = "dashboard-providers"
            mount_path = "/etc/grafana/provisioning/dashboards"
            read_only  = true
          }

          volume_mount {
            name       = "dashboards"
            mount_path = "/var/lib/grafana/dashboards"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/grafana"
          }
        }

        volume {
          name = "datasources"

          config_map {
            name = kubernetes_config_map_v1.grafana_provisioning.metadata[0].name

            items {
              key  = "datasources.yaml"
              path = "datasources.yaml"
            }
          }
        }

        volume {
          name = "dashboard-providers"

          config_map {
            name = kubernetes_config_map_v1.grafana_provisioning.metadata[0].name

            items {
              key  = "dashboards.yaml"
              path = "dashboards.yaml"
            }
          }
        }

        volume {
          name = "dashboards"

          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard.metadata[0].name
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

resource "kubernetes_service_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
    labels    = local.grafana_labels
  }

  spec {
    selector = local.grafana_labels

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 3000
      target_port = "http"
    }

    type = "ClusterIP"
  }
}
