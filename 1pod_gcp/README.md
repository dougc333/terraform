# One-Pod GKE Observability Lab

This macOS lab creates billable Google Cloud resources:

- one zonal GKE Standard cluster;
- one `e2-micro` shared-core node;
- one Artifact Registry Docker repository;
- one Go web-server Pod and private ClusterIP Service;
- one Prometheus Pod and private ClusterIP Service;
- a Mac load-test script that forwards into the cluster and prints Pod CPU.

The Services are not public. `kubectl port-forward` carries both the load-test
traffic and Prometheus UI traffic through the authenticated Kubernetes API.

## Cost and sizing

`e2-micro` is the smallest E2 shared-core VM. It has limited sustained CPU and
only 1 GB of memory, so it is suitable for this learning lab, not production.
GKE, the node disk, Artifact Registry, network traffic, and other Google Cloud
services can incur charges. Run `./scripts/destroy.sh` when finished.

If system Pods or Prometheus cannot schedule, use the next size:

```bash
export TF_VAR_machine_type=e2-small
./scripts/setup.sh
```

## Architecture

```text
Mac curl load test
        |
        | kubectl port-forward (authenticated tunnel)
        v
web Service -> Go web Pod -> /metrics
                              ^
                              |
Mac browser <- port-forward <- Prometheus Pod
```

## Mac prerequisites

Install Docker Desktop, Terraform, kubectl, and the Google Cloud CLI. For
Homebrew installations:

```bash
brew install terraform kubectl
brew install --cask google-cloud-sdk
```

Verify Docker Desktop is running:

```bash
docker info
```

Your Google Cloud project must have billing enabled. Your account needs enough
permission to enable APIs and create GKE, VPC, IAM, and Artifact Registry
resources.

## Authenticate and select a project

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
export TF_VAR_project_id=YOUR_PROJECT_ID
```

The first login is for `gcloud` and `kubectl`. Application Default Credentials
are used by Terraform's Google provider.

## Create the GKE lab

```bash
cd /Users/dc/terraform/1pod_gcp
./scripts/setup.sh
```

The script performs two Terraform applies:

1. creates GKE, the node pool, network, service account, and Artifact Registry;
2. builds an amd64 image on the Mac, pushes it, and creates the Kubernetes
   namespace, Deployments, and Services.

GKE creation can take several minutes.

## Terminal 1: open Prometheus

```bash
cd /Users/dc/terraform/1pod_gcp
./scripts/prometheus-ui.sh
```

Open <http://127.0.0.1:9090>. Useful PromQL queries:

```promql
rate(web_requests_total[30s])
```

```promql
increase(web_requests_total[1m])
```

```promql
rate(process_cpu_seconds_total[1m]) * 100
```

```promql
rate(web_request_duration_seconds_sum[30s])
/
rate(web_request_duration_seconds_count[30s])
```

## Terminal 2: run increasing load from the Mac

```bash
cd /Users/dc/terraform/1pod_gcp
./scripts/load-test.sh
```

The script creates a temporary port-forward to the private web Service, runs
four sequential stages, and samples `kubectl top pods` every five seconds:

| Stage | Concurrency | Duration | CPU work/request |
|---:|---:|---:|---:|
| 1 | 1 | 10 seconds | 250,000 |
| 2 | 5 | 15 seconds | 1,000,000 |
| 3 | 15 | 25 seconds | 3,000,000 |
| 4 | 30 | 30 seconds | 5,000,000 |

The full test takes about 80 seconds. High CPU work can reduce completed
requests per second because each request takes longer.

## Inspect the cluster

```bash
KUBECONFIG=.kubeconfig kubectl get nodes
KUBECONFIG=.kubeconfig kubectl -n web-observability get all
KUBECONFIG=.kubeconfig kubectl -n web-observability logs deployment/web
KUBECONFIG=.kubeconfig kubectl -n web-observability logs deployment/prometheus
```

## Rebuild after changing the Go application

Run `./scripts/setup.sh` again. The image uses the `dev` tag and the Deployment
uses `imagePullPolicy: Always`; the source-hash annotation forces a rollout.

## Destroy all GCP lab resources

Keep `TF_VAR_project_id` set to the same project, then run:

```bash
cd /Users/dc/terraform/1pod_gcp
./scripts/destroy.sh
```

The GCP state is stored in `terraform-gcp.tfstate`. On the first setup, copied
kind state files are preserved under `kind-state-backup/`; they are never
imported into or used by the GCP deployment.
