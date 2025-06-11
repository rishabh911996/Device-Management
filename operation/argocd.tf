resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.8"

  values = [
    yamlencode({
      # Configure ArgoCD server for easy access
      server = {
        service = {
          type     = "NodePort" # Expose via NodePort for Docker Desktop
          nodePortHttp = 30081      # Access at localhost:30081
        }
        extraArgs = [
          "--insecure" # Disable TLS for development
        ]
        config = {
          # Allow anonymous access for easier development
          "accounts.anonymous"         = "apiKey"
          "accounts.anonymous.enabled" = "true"
        }
      }

      # Resource limits for ArgoCD components
      controller = {
        resources = {
          requests = { memory = "256Mi", cpu = "100m" }
          limits   = { memory = "512Mi", cpu = "500m" }
        }
      }

      repoServer = {
        resources = {
          requests = { memory = "128Mi", cpu = "50m" }
          limits   = { memory = "256Mi", cpu = "100m" }
        }
      }

      # Enable ApplicationSet for managing multiple apps
      applicationSet = {
        enabled = true
        resources = {
          requests = { memory = "64Mi", cpu = "25m" }
          limits   = { memory = "128Mi", cpu = "50m" }
        }
      }

      # Disable components we don't need
      notifications = { enabled = false }
      dex           = { enabled = false }

      global = {
        image = { tag = "v2.13.1" }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

resource "kubernetes_secret" "git_repo_secret" {
  metadata {
    name      = "git-repo-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type = "git"
    url  = "https://github.com/rishabh911996/Device-Management"
  }

  depends_on = [helm_release.argocd]
}

# Output ArgoCD access information for Docker Desktop
output "argocd_info" {
  value = {
    url              = "http://localhost:30081"
    username         = "admin"
    password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    note             = "Make sure Docker Desktop Kubernetes is enabled"
  }
}

# Verify Docker Desktop Kubernetes context
data "external" "k8s_context" {
  program = ["bash", "-c", "echo '{\"context\":\"'$(kubectl config current-context)'\"}'"]
}

output "kubernetes_context" {
  value       = data.external.k8s_context.result.context
  description = "Current Kubernetes context (should be docker-desktop)"
}