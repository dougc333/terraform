# Local kind HPA Scale Test

This project creates a single-node kind cluster, builds a CPU-intensive Go web
server, and deploys it behind a ClusterIP Service. Metrics Server supplies CPU
data to an `autoscaling/v2` HPA that can scale the Deployment from one Pod to
two Pods. Prometheus records the traffic, application, CPU, and replica metrics;
Grafana displays the complete scale-up and scale-down cycle.

The load generator is a k6 Kubernetes Job. Traffic stays inside the cluster:

```text
k6 Job -> web ClusterIP Service -> Ready web Pods
   |                  /metrics -> Prometheus -> Grafana
   +-- remote write ------------------^

web CPU -> Metrics Server -> HPA -> Deployment replicas
HPA/Deployment state -> kube-state-metrics -> Prometheus
```

## Start the lab

Start Docker Desktop, then run:

```bash
cd /Users/dc/terraform/2pods_grafana_prom/2pods
./scripts/setup.sh
```

The setup script creates the kind cluster, installs Metrics Server, applies the
Terraform configuration, and waits for the web, Prometheus,
kube-state-metrics, and Grafana Deployments.

## Open the Grafana dashboard

In a second terminal, run:

```bash
cd /Users/dc/terraform/2pods_grafana_prom/2pods
./scripts/grafana-ui.sh
```

This keeps a local port-forward open and opens the provisioned **HPA
Autoscaling Lab** dashboard at `http://127.0.0.1:3000`. No login is required for
this local lab. Keep this terminal running while viewing the dashboard.

## Run and verify the autoscaling cycle

```bash
./scripts/run-hpa-test.sh
```

The k6 Job performs five stages:

1. one request/second baseline;
2. ramp to 25 requests/second;
3. hold high load for two minutes;
4. ramp down to one request/second;
5. remain at low load long enough for HPA scale-down.

The verification script samples Kubernetes every five seconds and fails unless
it observes two Ready web Pods followed by a return to one Ready Pod. Each run
writes a TSV timeline and a metrics-verification report under `results/`. It
also verifies that Prometheus contains the traffic ramp, CPU above the HPA
target, and the 1 -> 2 -> 1 replica history, and that Grafana's dashboard is
provisioned.

The dashboard refreshes every five seconds and graphs:

- k6 request rate and requests actually served by the web Pods;
- HPA CPU utilization alongside its 50% target;
- current and desired replica counts;
- CPU utilization by individual Pod;
- server-side p95 request latency.

To inspect raw Prometheus metrics instead, run:

```bash
./scripts/prometheus-ui.sh
```

Then open `http://127.0.0.1:9090` and try:

```promql
sum(rate(k6_http_reqs_total[15s]))
max(kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler="web"})
```

Useful commands while the test runs:

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling get hpa web --watch
```

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling get pods --watch
```

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling describe hpa web
```

## Destroy

```bash
./scripts/destroy.sh
```
