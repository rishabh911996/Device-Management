resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "27.20.0"

  values = [
    yamlencode({
      server = {
        service = {
          type     = "NodePort"
          nodePort = 30090
        }
        persistentVolume = {
          enabled = true
          size    = "2Gi"  # Reduced from 10Gi
        }
        retention = "7d"  # Reduced from 30d
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "100m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
      }
      alertmanager = {
        enabled = true
        service = {
          type     = "NodePort"
          nodePort = 30093
        }
        persistentVolume = {
          enabled = true
          size    = "1Gi"  # Reduced from 5Gi
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
      }
      nodeExporter = {
        enabled = true
        resources = {
          requests = {
            memory = "32Mi"
            cpu    = "25m"
          }
          limits = {
            memory = "64Mi"
            cpu    = "50m"
          }
        }
      }
      kubeStateMetrics = {
        enabled = true
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
      }
      pushgateway = {
        enabled = true
        resources = {
          requests = {
            memory = "32Mi"
            cpu    = "25m"
          }
          limits = {
            memory = "64Mi"
            cpu    = "50m"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}