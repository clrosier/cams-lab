# RoboPD2 - Full Stack Application

Complete deployment for the RoboPD2 application stack managed with Flux.

## Architecture

The application consists of three main components:

1. **PostgreSQL Database** (`postgres/`) - Data persistence layer
2. **FastAPI Backend** (`api/`) - REST API service
3. **Vue Frontend** (`web/`) - Web user interface

## Directory Structure

```
robopd2/
├── namespace.yaml          # Kubernetes namespace
├── kustomization.yaml      # Main kustomization (includes all components)
├── postgres/               # PostgreSQL database
│   ├── kustomization.yaml
│   ├── helmrepo.yaml
│   ├── postgres-secret.yaml
│   └── postgres-helmrelease.yaml
├── api/                    # FastAPI backend
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── web/                    # Vue frontend
    ├── kustomization.yaml
    ├── deployment.yaml
    └── service.yaml
```

## Components

### PostgreSQL Database

- **PostgreSQL 16** via Bitnami Helm chart
- Single replica (standalone mode)
- 10Gi persistent storage
- Prometheus metrics enabled

#### Node Selection

The deployment is configured to:
1. **Avoid the control-plane node** - workloads prefer worker nodes
2. **Prefer Pi 5 nodes** (if labeled) - faster performance than Pi 4

##### Node Labels

Nodes are labeled for scheduling preferences:

```bash
# Pi 5 workers (preferred for databases)
kubectl label node kube-worker01 node.kubernetes.io/pi-type=5
kubectl label node kube-worker02 node.kubernetes.io/pi-type=5

# Pi 4 worker
kubectl label node kube-worker03 node.kubernetes.io/pi-type=4
```

#### Secret Management

Before deploying, you MUST encrypt the PostgreSQL credentials:

1. Edit `postgres/postgres-secret.yaml` and set real passwords
2. Encrypt with SOPS:
   ```bash
   source scripts/sops-env.sh
   sops --encrypt --in-place clusters/home/apps/robopd2/postgres/postgres-secret.yaml
   ```

#### Connection Details

Once deployed, connect to PostgreSQL from within the cluster:

- **Host:** `postgresql.robopd2.svc.cluster.local`
- **Port:** `5432`
- **Database:** `robopd2`
- **Username:** `robopd2`
- **Password:** (from secret)

#### Resources

Configured for Raspberry Pi constraints:
- **Requests:** 100m CPU, 256Mi memory
- **Limits:** 1 CPU, 1Gi memory
- **PostgreSQL tuned for 8GB RAM nodes**

### FastAPI Backend

- REST API service running on port 8000
- Connects to PostgreSQL database
- Health checks at `/health`
- Resource-constrained for Raspberry Pi

#### Configuration

The API deployment expects:
- Container image: `robopd2-api:latest` (update in `api/deployment.yaml`)
- Environment variables:
  - `DATABASE_URL` - Auto-configured to connect to PostgreSQL
  - `POSTGRES_PASSWORD` - Retrieved from postgres-credentials secret

#### Resources

- **Requests:** 100m CPU, 128Mi memory
- **Limits:** 500m CPU, 512Mi memory

#### Service

- **Service Name:** `robopd2-api`
- **Type:** ClusterIP
- **Port:** 80 (targets container port 8000)
- **Internal URL:** `http://robopd2-api.robopd2.svc.cluster.local`

### Vue Frontend

- Static web application served on port 80
- Connects to FastAPI backend
- Resource-constrained for Raspberry Pi

#### Configuration

The web deployment expects:
- Container image: `robopd2-web:latest` (update in `web/deployment.yaml`)
- Environment variables:
  - `VITE_API_URL` - Backend API URL (defaults to internal service)

#### Resources

- **Requests:** 50m CPU, 64Mi memory
- **Limits:** 200m CPU, 256Mi memory

#### Service

- **Service Name:** `robopd2-web`
- **Type:** ClusterIP
- **Port:** 80
- **Internal URL:** `http://robopd2-web.robopd2.svc.cluster.local`

## Deployment

All components are managed by Flux and will be automatically deployed when changes are committed to the repository.

### Manual Deployment Check

To verify deployment status:

```bash
# Check all resources in the namespace
kubectl get all -n robopd2

# Check Flux HelmRelease status
flux get helmreleases -n robopd2

# Check pod logs
kubectl logs -n robopd2 -l app=robopd2-api
kubectl logs -n robopd2 -l app=robopd2-web
```

## Next Steps

1. **Update Container Images**: Replace `robopd2-api:latest` and `robopd2-web:latest` in the deployment manifests with your actual container registry paths
2. **Configure Image Automation** (optional): Set up Flux ImageRepository and ImagePolicy for automated image updates
3. **Add Ingress** (optional): Configure ingress rules to expose the web frontend externally
4. **Add ConfigMaps/Secrets**: Add any additional configuration needed for your API or web components

## Monitoring

PostgreSQL metrics are exposed for Prometheus scraping. A ServiceMonitor is created automatically.
