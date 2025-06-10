variable "monitoring_namespace" {
  description = "The namespace for the monitoring resources."
  type        = string
  default     = "monitoring"
}

variable "argo_namespace" {
  description = "The namespace for the Argo resources."
  type        = string
  default     = "argocd"
}

variable "grafana_admin_pwd" {
  description = "The password for the Grafana admin user."
  type        = string
  default     = "admin"
}