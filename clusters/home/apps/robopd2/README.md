# RoboPD2 - PostgreSQL Database

PostgreSQL database deployment for the RoboPD2 application.

## Components

- **PostgreSQL 16** via Bitnami Helm chart
- Single replica (standalone mode)
- 10Gi persistent storage
- Prometheus metrics enabled

## Node Selection

The deployment is configured to:
1. **Avoid the control-plane node** - workloads prefer worker nodes
2. **Prefer Pi 5 nodes** (if labeled) - faster performance than Pi 4

### Node Labels

Nodes are labeled for scheduling preferences:

```bash
# Pi 5 workers (preferred for databases)
kubectl label node kube-worker01 node.kubernetes.io/pi-type=5
kubectl label node kube-worker02 node.kubernetes.io/pi-type=5

# Pi 4 worker
kubectl label node kube-worker03 node.kubernetes.io/pi-type=4
```

## Secret Management

Before deploying, you MUST encrypt the PostgreSQL credentials:

1. Edit `postgres-secret.yaml` and set real passwords
2. Encrypt with SOPS:
   ```bash
   source scripts/sops-env.sh
   sops --encrypt --in-place clusters/home/apps/robopd2/postgres-secret.yaml
   ```

## Connection Details

Once deployed, connect to PostgreSQL from within the cluster:

- **Host:** `postgresql.robopd2.svc.cluster.local`
- **Port:** `5432`
- **Database:** `robopd2`
- **Username:** `robopd2`
- **Password:** (from secret)

## Connecting from another pod

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://robopd2:$(POSTGRES_PASSWORD)@postgresql.robopd2.svc.cluster.local:5432/robopd2"
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials
        key: password
```

## Monitoring

PostgreSQL metrics are exposed for Prometheus scraping. A ServiceMonitor is created automatically.

## Resources

Configured for Raspberry Pi constraints:
- **Requests:** 100m CPU, 256Mi memory
- **Limits:** 1 CPU, 1Gi memory
- **PostgreSQL tuned for 8GB RAM nodes**
