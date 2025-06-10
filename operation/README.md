# Device Management - Monitoring Stack

This repository contains Terraform configurations to deploy a comprehensive monitoring stack on Minikube using Helm charts.

## 🏗️ Architecture Overview

The monitoring stack includes:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards  
- **Loki** - Log aggregation (single-tenant mode)
- **Promtail** - Log collection agent
- **Tempo** - Distributed tracing
- **AlertManager** - Alert handling

## 📋 Prerequisites

- **Minikube** installed and running
- **kubectl** configured to work with Minikube
- **Terraform** >= 1.0
- **Helm** >= 3.0

## 🚀 Quick Start

### 1. Start Minikube
```bash
# Start Minikube with sufficient resources
minikube start --memory=8192 --cpus=4 --disk-size=20g

# Enable required addons
minikube addons enable metrics-server
minikube addons enable storage-provisioner
```

### 2. Deploy the Stack
```bash
cd /Users/rishabhgupta/repo/Device-Management/operation

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the monitoring stack
terraform apply
```

### 3. Verify Deployment
```bash
# Check all pods are running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring
```

## 🌐 Accessing Services

### Grafana Dashboard
- **URL**: `http://<minikube-ip>:30080`
- **Username**: `admin`
- **Password**: `admin` (configured in variables.tf)

```bash
# Get Minikube IP
minikube ip

# Or use minikube service (recommended)
minikube service grafana -n monitoring
```

### Prometheus
- **URL**: `http://<minikube-ip>:30090`
```bash
minikube service prometheus-server -n monitoring
```

### AlertManager
- **URL**: `http://<minikube-ip>:30093`
```bash
minikube service prometheus-alertmanager -n monitoring
```

## 📊 Pre-configured Dashboards

Grafana comes with pre-configured:

### Datasources
- **Prometheus** - Metrics (default datasource)
- **Loki** - Logs (single-tenant mode, no authentication)
- **Tempo** - Distributed traces

### Default Dashboards
- **Prometheus Stats** (GrafanaLabs ID: 2)
- **Kubernetes Cluster Monitoring** (GrafanaLabs ID: 7249)
- **Kubernetes Logs** (GrafanaLabs ID: 15141)
- **Loki Logs Dashboard** (GrafanaLabs ID: 13639)

## 🔧 Configuration Files

### Core Infrastructure
- **`providers.tf`** - Terraform providers for Kubernetes and Helm
- **`namespaces.tf`** - Kubernetes namespaces (monitoring, argocd)
- **`variables.tf`** - Configuration variables

### Monitoring Components
- **`prometheus.tf`** - Prometheus server, AlertManager, Node Exporter, Kube State Metrics, Pushgateway
- **`grafana_stack.tf`** - Grafana, Loki, Promtail, and Tempo

## ⚙️ Resource Configuration

All components are configured with minimal resource requirements for Minikube:

### Prometheus Stack
- **Prometheus Server**: 256Mi memory, 100m CPU (2Gi storage, 7d retention)
- **AlertManager**: 64Mi memory, 50m CPU (1Gi storage)
- **Node Exporter**: 32Mi memory, 25m CPU
- **Kube State Metrics**: 64Mi memory, 50m CPU
- **Pushgateway**: 32Mi memory, 25m CPU

### Grafana Stack
- **Grafana**: 128Mi memory, 100m CPU (persistence disabled for stability)
- **Loki**: 128Mi memory, 100m CPU (SingleBinary mode, 2Gi storage)
- **Tempo**: 128Mi memory, 100m CPU (2Gi storage, 12h retention)
- **Promtail**: 128Mi memory, 100m CPU

## 🗂️ Storage & Retention

Persistent volumes are configured for:
- **Prometheus**: 2Gi (7 days retention)
- **Loki**: 2Gi (filesystem storage)
- **Tempo**: 2Gi (12 hours retention)
- **AlertManager**: 1Gi
- **Grafana**: Persistence disabled (uses emptyDir for stability on Minikube)

## 📝 Log Collection

### Automatic Log Collection
Promtail automatically collects logs from:
- All Kubernetes pods (including monitoring stack)
- Container logs from `/var/log/containers/`
- Pod logs from `/var/log/pods/`

### Querying Logs in Grafana
Use LogQL in Grafana's Explore section:

```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Specific service logs
{namespace="monitoring", container="prometheus-server"}
{namespace="monitoring", container="grafana"}
{namespace="monitoring", container="loki"}

# Filter by log level
{namespace="monitoring"} |= "error"
{namespace="monitoring"} |= "warn"

# All application logs
{namespace!="monitoring"}
```

## 🔍 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
kubectl describe pod <pod-name> -n monitoring
```

### View Logs
```bash
# View specific component logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=loki -c loki
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-server
```

### Test Loki Connectivity
```bash
# Port forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Test Loki API (should return labels)
curl "http://localhost:3100/loki/api/v1/labels"

# Query recent logs
curl "http://localhost:3100/loki/api/v1/query_range?query=%7Bnamespace%3D%22monitoring%22%7D&start=$(date -d '1 hour ago' +%s)000000000&end=$(date +%s)000000000"
```

### Port Forward (Alternative Access)
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Access: http://localhost:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Access: http://localhost:9090

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100
# Access: http://localhost:3100
```

### Resource Issues
If pods fail due to insufficient resources:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Increase Minikube resources
minikube stop
minikube start --memory=8192 --cpus=4
```

### Common Issues

#### Grafana "no org id" Error
This has been resolved by:
- Setting `auth_enabled = false` in Loki configuration
- Using single-tenant mode
- Proper datasource configuration in Grafana

#### Pod Restart Issues
- Loki uses SingleBinary deployment mode with chunksCache disabled
- Grafana persistence is disabled to avoid permission issues on Minikube
- All components have appropriate resource limits

## 🧹 Cleanup

```bash
# Destroy the monitoring stack
terraform destroy

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

## 📝 Customization

### Variables
Edit `variables.tf` to customize:
- `monitoring_namespace` - Namespace for monitoring components (default: "monitoring")
- `argo_namespace` - Namespace for ArgoCD (default: "argocd")
- `grafana_admin_pwd` - Grafana admin password (default: "admin")

### Resource Limits
Modify resource requests/limits in:
- `prometheus.tf` - Prometheus stack components
- `grafana_stack.tf` - Grafana, Loki, Promtail, Tempo

### Additional Dashboards
Add more dashboards in `grafana_stack.tf` under the `dashboards.default` section:

```terraform
dashboards = {
  default = {
    # Add custom dashboard
    my-custom-dashboard = {
      gnetId     = 12345
      revision   = 1
      datasource = "Prometheus"
    }
  }
}
```

### Loki Configuration
The current setup uses:
- **SingleBinary deployment mode** for simplicity
- **Filesystem storage** (suitable for development)
- **No authentication** (single-tenant mode)
- **TSDB schema v13** for better performance

## 🔗 Service URLs Quick Reference

After deployment, access services at:
- **Grafana**: `http://$(minikube ip):30080` (admin/admin)
- **Prometheus**: `http://$(minikube ip):30090`  
- **AlertManager**: `http://$(minikube ip):30093`

```bash
# Quick access script
MINIKUBE_IP=$(minikube ip)
echo "Grafana: http://$MINIKUBE_IP:30080 (admin/admin)"
echo "Prometheus: http://$MINIKUBE_IP:30090"
echo "AlertManager: http://$MINIKUBE_IP:30093"
echo ""
echo "To access via minikube service:"
echo "minikube service grafana -n monitoring"
echo "minikube service prometheus-server -n monitoring"
echo "minikube service prometheus-alertmanager -n monitoring"
```

## 🎯 Next Steps

1. **Configure Alerts** - Set up custom alerting rules in Prometheus
2. **Add Custom Dashboards** - Import or create dashboards for your applications
3. **Deploy ArgoCD** - Add GitOps capabilities using the configured namespace
4. **Application Monitoring** - Instrument your applications to send metrics/traces to the stack
5. **Log Analysis** - Use Grafana's Explore feature to analyze logs with LogQL
6. **Distributed Tracing** - Configure applications to send traces to Tempo
7. **Production Setup** - Enable persistence, authentication, and proper resource limits for production use

## 📚 Useful LogQL Queries

```logql
# Monitor errors across all services
{namespace="monitoring"} |= "error" | json

# Track specific container restarts
{namespace="monitoring"} |= "restarting"

# Monitor resource usage patterns
{namespace="monitoring"} |~ "memory|cpu|disk"

# Application-specific logs (replace with your app namespace)
{namespace="default"} | json | line_format "{{.timestamp}} {{.level}} {{.message}}"
```

This monitoring stack provides a solid foundation for observability in your Kubernetes environment with metrics, logs, and traces all integrated into a single Grafana interface.