# Grafana deployment - Fixed for Docker Desktop with proper lifecycle management
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "9.2.2"

  # Add lifecycle management to handle conflicts
  lifecycle {
    create_before_destroy = true
  }

  # Helm-specific options to handle conflicts
  cleanup_on_fail = true
  force_update    = true
  recreate_pods   = true
  timeout         = 300

  values = [
    yamlencode({
      adminPassword = var.grafana_admin_pwd
      service = {
        type     = "NodePort"
        nodePort = 30080
        # Add annotation to help with updates
        annotations = {
          "helm.sh/resource-policy" = "keep"
        }
      }
      persistence = {
        enabled = false # Good for Docker Desktop
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
              name      = "Loki"
              type      = "loki"
              # Use the simpler service name instead of FQDN
              url       = "http://loki:3100"
              access    = "proxy"
              isDefault = false
              jsonData = {
                maxLines = 1000
                timeout  = 30
                timeInterval = "30s"
                # Update health checks
                healthchecks = {
                  disableHealthcheck = true
                }
                # Update logs volume configuration
                logsVolume = {
                  enabled = true
                  defaultQuery = "{namespace=\"monitoring\"}"
                }
                # Add features for drilldown
                features = {
                  analytics = true
                  sensitivityLabels = false
                }
                queryTimeout = "30s"
                alertmanager = {
                  implementation = "prometheus"
                }
              }
              # Remove secureJsonData as it's not needed
            },
            {
              name   = "Tempo"
              type   = "tempo"
              url    = "http://tempo.${var.monitoring_namespace}.svc.cluster.local:3100" # Fixed port
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

# Loki deployment - Simplified for Docker Desktop
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  # Use the main loki-stack chart as in the working solution
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "2.9.11"

  # Simplify the configuration
  set {
    name  = "loki.enabled"
    value = "true"
  }

  values = [
    yamlencode({
      loki = {
        auth_enabled = false
        config = {
          ingester = {
            chunk_idle_period = "5m"
            chunk_retain_period = "30s"
            lifecycler = {
              ring = {
                kvstore = {
                  store = "inmemory"
                }
                replication_factor = 1
              }
            }
          }
          schema_config = {
            configs = [{
              from = "2020-10-24"
              store = "boltdb-shipper"
              object_store = "filesystem"
              schema = "v11"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }]
          }
          storage_config = {
            boltdb_shipper = {
              active_index_directory = "/data/loki/index"
              cache_location = "/data/loki/cache"
              cache_ttl = "24h"
              shared_store = "filesystem"
            }
            filesystem = {
              directory = "/data/loki/chunks"
            }
          }
          limits_config = {
            max_cache_freshness_per_query = "10m"
            split_queries_by_interval = "15m"
            max_query_parallelism = 32
            max_entries_limit_per_query = 5000
          }
          query_scheduler = {
            max_outstanding_requests_per_tenant = 2048
          }
          querier = {
            engine = {
              timeout = "3m"
              max_look_back_period = "5m"
            }
          }
        }
      }
      serviceMonitor = {
        enabled = true
        interval = "30s"
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Tempo deployment - Optimized for Docker Desktop
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "1.21.1"

  # Add lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Add these options to handle StatefulSet updates
  cleanup_on_fail = true
  force_update    = true
  timeout         = 600

  values = [
    yamlencode({
      tempo = {
        retention = "6h"
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
        enabled = false # Disable persistence for easier updates in Docker Desktop
      }

      resources = {
        requests = {
          memory = "64Mi"
          cpu    = "50m"
        }
        limits = {
          memory = "128Mi"
          cpu    = "100m"
        }
      }

      serviceMonitor = { enabled = false }
      service = {
        type = "ClusterIP"
        ports = [
          {
            name       = "http"
            port       = 3100
            targetPort = 3100
          }
        ]
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Output monitoring stack information
output "monitoring_stack_info" {
  value = {
    grafana_url         = "http://localhost:30080"
    grafana_credentials = "admin / ${var.grafana_admin_pwd}"
    prometheus_url      = "http://localhost:30090"
    alertmanager_url    = "http://localhost:30093"
    note                = "All services accessible on localhost with Docker Desktop"
  }
  sensitive   = true
  description = "Monitoring stack access information"
}