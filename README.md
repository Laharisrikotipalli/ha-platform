# Highly Available Stateful Platform on Kubernetes

## Project Overview

A production-grade HA platform deployed on Kubernetes featuring:

- Stateless Web Application (3 replicas with anti-affinity)
- PostgreSQL StatefulSet (1 Primary + 2 Standbys with streaming replication)
- Persistent Storage via PVCs (1Gi per replica)
- PodDisruptionBudgets (minAvailable: 2 for both web and DB)
- Zero-downtime Rolling Updates
- Automated Daily Backups via CronJob

---

## Architecture
## Architecture Overview

![Architecture Diagram](docs/architecture.svg)

---

## Prerequisites

- Docker Desktop
- minikube (`curl -Lo ~/bin/minikube.exe https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe`)
- kubectl

Verify cluster is running:
```bash
kubectl cluster-info
kubectl get nodes
```

---

## Project Structure

```
ha-platform/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── init-replication.sh       # Reference copy of the init script (also in configmap)
├── README.md
│
├── src/
│   └── app.py
│
└── k8s/
    ├── namespace.yaml
    ├── postgres-secret.yaml
    ├── postgres-configmap.yaml
    ├── postgres-headless-svc.yaml
    ├── postgres-statefulset.yaml
    ├── postgres-pdb.yaml
    ├── backup-pvc.yaml
    ├── backup-cronjob.yaml
    ├── web-deployment.yaml
    ├── web-service.yaml
    └── web-pdb.yaml
```

---

## Step-by-Step Deployment

### Step 1 — Start cluster (3 nodes for anti-affinity)
```bash
minikube start --nodes 3 --driver=docker --kubernetes-version=v1.32.0
kubectl get nodes
```

### Step 2 — Apply all manifests in order
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/postgres-configmap.yaml
kubectl apply -f k8s/backup-pvc.yaml
kubectl apply -f k8s/postgres-headless-svc.yaml
kubectl apply -f k8s/web-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/web-deployment.yaml
kubectl apply -f k8s/postgres-pdb.yaml
kubectl apply -f k8s/web-pdb.yaml
kubectl apply -f k8s/backup-cronjob.yaml
```

### Step 3 — Watch pods come up
```bash
kubectl get pods -n ha-platform -w
```
Wait until all 6 pods show `1/1 Running` (postgres-0 starts first, then 1, then 2).

### Step 4 — Verify replication
```bash
kubectl exec -n ha-platform postgres-0 -- psql -U postgres -c \
  "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
```
Expected: 2 rows with `state = streaming`.

### Step 5 — Access the web app
```bash
minikube service web-service -n ha-platform --url
curl http://<url>/
curl http://<url>/health
curl http://<url>/ready
```

---

## Verification Commands

```bash
# All pods across nodes
kubectl get pods -n ha-platform -o wide

# PVCs (3 x 1Gi Bound)
kubectl get pvc -n ha-platform

# Services (headless + NodePort)
kubectl get svc -n ha-platform

# PodDisruptionBudgets
kubectl get pdb -n ha-platform

# CronJob
kubectl get cronjob -n ha-platform

# Replication status
kubectl exec -n ha-platform postgres-0 -- psql -U postgres -c \
  "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
```

---

## Resilience Testing (Node Drain)

```bash
# Check pod placement
kubectl get pods -n ha-platform -o wide

# Drain a worker node
kubectl drain minikube-m02 --ignore-daemonsets --delete-emptydir-data

# Watch pods reschedule to healthy nodes
kubectl get pods -n ha-platform -o wide -w

# Verify replication resumed after drain
kubectl exec -n ha-platform postgres-0 -- psql -U postgres -c \
  "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

# Restore the node
kubectl uncordon minikube-m02
```

**Expected:** Evicted pods reschedule automatically. Replication resumes with 2 streaming standbys.

---

## Manual Backup Test

```bash
kubectl create job --from=cronjob/postgres-backup manual-backup-test -n ha-platform
kubectl logs -n ha-platform job/manual-backup-test
```

---

## Docker Compose (Automated Logic Verification)

```bash
docker-compose up --build
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/ready
docker-compose down
```

---

## Verification Screenshots

| # | Screenshot | What it proves |
|---|---|---|
| 1 | `kubectl get nodes` | 3-node cluster |
| 2 | `kubectl get pods -o wide` | Pods spread across nodes |
| 3 | `pg_stat_replication` | 2 streaming standbys |
| 4 | `kubectl get pvc` | 3 PVCs Bound |
| 5 | `kubectl get pdb` | PDBs with minAvailable: 2 |
| 6 | `kubectl get cronjob` | Daily backup scheduled |
| 7 | `curl /` `/health` `/ready` | Web app working |
| 8 | `kubectl drain` output | Node eviction |
| 9 | Pods after drain | Rescheduled to healthy nodes |
| 10 | `pg_stat_replication` after drain | Replication resumed |

---

## Author

Name: Lahari Sri
Project: Architect Highly Available Stateful Platform on Kubernetes