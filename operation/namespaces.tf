resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argo_namespace
  }

}