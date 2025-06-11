resource "kubernetes_manifest" "weather_service" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "weather-service"
      namespace = "argocd"  # ArgoCD namespace where Applications should be created
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
      labels = {
        app = "weather-service"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/rishabh911996/Device-Management"
        targetRevision = "observability"  # Points to your observability branch
        path           = "deploy/helm/weather-service"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"  # Points to local Docker Desktop K8s
        namespace = "weather-service"
      }
      syncPolicy = {
        automated = {
          prune       = true
          selfHeal    = true
          allowEmpty  = false
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.git_repo_secret
  ]
}

# Create a NodePort service to access the weather service from localhost
resource "kubernetes_manifest" "weather_service_nodeport" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "weather-service-nodeport"
      namespace = "weather-service"
    }
    spec = {
      selector = {
        app = "weather-service"
      }
      ports = [
        {
          port       = 80
          targetPort = 8080
          nodePort   = 30082 # Access on localhost:30082
        }
      ]
      type = "NodePort"
    }
  }

  depends_on = [
    kubernetes_manifest.weather_service
  ]
}

# Add an output to show access info
output "weather_service_info" {
  value = {
    argocd_app_url = "http://localhost:30081/applications/weather-service"
    service_url    = "http://localhost:30082"
  }
}