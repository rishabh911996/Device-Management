# Grafana deployment - Fixed for Minikube
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "9.2.2"

  values = [
    yamlencode({
      adminPassword = var.grafana_admin_pwd
      service = {
        type     = "NodePort"
        nodePort = 30080
      }
      persistence = {
        enabled = false  # Temporarily disable persistence to avoid issues
      }
      
      resources = {
        requests = {
          memory = "128Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "256Mi"
          cpu    = "200m"
        }
      }
      
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.${var.monitoring_namespace}.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            },
            {
              name   = "Loki"
              type   = "loki"
              url    = "http://loki.${var.monitoring_namespace}.svc.cluster.local:3100"
              access = "proxy"
              # Add headers to disable org requirement
              jsonData = {
                maxLines = 1000
              }
              # No authentication headers needed for single-tenant mode
            },
            {
              name   = "Tempo"
              type   = "tempo"
              url    = "http://tempo.${var.monitoring_namespace}.svc.cluster.local:3100"
              access = "proxy"
            }
          ]
        }
      }
      
      dashboards = {
        default = {
          prometheus-stats = {
            gnetId     = 2
            revision   = 2
            datasource = "Prometheus"
          }
          kubernetes-cluster = {
            gnetId     = 7249
            revision   = 1
            datasource = "Prometheus"
          }
          kubernetes-logs = {
            gnetId     = 15141
            revision   = 1
            datasource = "Loki"
          }
          loki-logs = {
            gnetId     = 13639
            revision   = 2
            datasource = "Loki"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus,
    helm_release.loki,
    helm_release.tempo
  ]
}

# Loki deployment - Fixed for Grafana integration
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "6.30.1"

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"
      loki = {
        auth_enabled = false  # Disable authentication for single-tenant mode
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
        schemaConfig = {
          configs = [
            {
              from         = "2020-10-24"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
        # Add server configuration to disable multi-tenancy
        server = {
          http_listen_port = 3100
          grpc_listen_port = 9095
        }
        # Limits configuration
        limits_config = {
          reject_old_samples = true
          reject_old_samples_max_age = "168h"
          allow_structured_metadata = false
        }
      }
      singleBinary = {
        replicas = 1
        persistence = {
          enabled = true
          size    = "2Gi"
        }
        resources = {
          requests = {
            memory = "128Mi"
            cpu    = "100m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
      }
      # Disable chunksCache which was causing memory issues
      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }
      # Disable other deployment modes
      backend = {
        replicas = 0
      }
      read = {
        replicas = 0
      }
      write = {
        replicas = 0
      }
      ingester = {
        replicas = 0
      }
      querier = {
        replicas = 0
      }
      queryFrontend = {
        replicas = 0
      }
      queryScheduler = {
        replicas = 0
      }
      distributor = {
        replicas = 0
      }
      compactor = {
        replicas = 0
      }
      indexGateway = {
        replicas = 0
      }
      bloomCompactor = {
        replicas = 0
      }
      bloomGateway = {
        replicas = 0
      }
      monitoring = {
        serviceMonitor = {
          enabled = false
        }
      }
      test = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Enhanced Promtail configuration for comprehensive log collection
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "6.17.0"

  values = [
    yamlencode({
      config = {
        lokiAddress = "http://loki.${var.monitoring_namespace}.svc.cluster.local:3100/loki/api/v1/push"
      }
      
      resources = {
        requests = {
          memory = "128Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "256Mi"
          cpu    = "200m"
        }
      }
      
      serviceMonitor = {
        enabled = false
      }
      
      serviceAccount = {
        create = true
      }
      
      rbac = {
        create = true
        pspEnabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.loki
  ]
}

# Tempo deployment - Minimal resources
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "1.21.1"

  values = [
    yamlencode({
      tempo = {
        retention = "12h"  # Reduced from 24h
        storage = {
          trace = {
            backend = "local"
            local = {
              path = "/var/tempo/traces"
            }
          }
        }
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
          jaeger = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:14250"
              }
              thrift_http = {
                endpoint = "0.0.0.0:14268"
              }
            }
          }
        }
      }
      persistence = {
        enabled = true
        size    = "2Gi"  # Reduced from 10Gi
      }
      resources = {
        requests = {
          memory = "128Mi"
          cpu    = "100m"
        }
        limits = {
          memory = "256Mi"
          cpu    = "200m"
        }
      }
      serviceMonitor = {
        enabled = false  # Disable until Prometheus Operator is installed
      }
      service = {
        type = "ClusterIP"
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}