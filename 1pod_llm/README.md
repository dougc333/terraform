# One-Pod Kubernetes Observability Lab

This local macOS lab creates:

- one Go web-server Pod managed by a Deployment;
- one ClusterIP Service for the web server;
- one Prometheus server that scrapes the web server every two seconds;
- one Grafana server with a pre-provisioned Prometheus dashboard;
- Metrics Server for `kubectl top` CPU and memory readings;
- a staged load test that increases concurrency and CPU work.

## Architecture

```text
curl load test -> kubectl port-forward -> web Service -> web Pod
                                                   -> /metrics
                                                        ^
                                                        |
Prometheus UI <- kubectl port-forward <- Prometheus Pod-+
Grafana UI    <- kubectl port-forward <- Grafana Pod ----+
```

## Start

```bash
./scripts/setup.sh
```

## Open Prometheus

In a second terminal:

```bash
./scripts/prometheus-ui.sh
```

## Open Grafana

In a second terminal:

```bash
./scripts/grafana-ui.sh
```

Grafana opens at <http://127.0.0.1:3000> with anonymous local viewer access.
The provisioned **One-Pod Observability** dashboard shows request rate,
requests per minute, process CPU, memory, average request duration, and
in-flight requests. Prometheus remains the metric collector and data store;
Grafana queries Prometheus and provides the dashboard.

Useful queries:

```promql
rate(web_requests_total[30s])
```

```promql
rate(web_request_duration_seconds_sum[30s])
/
rate(web_request_duration_seconds_count[30s])
```

```promql
web_requests_in_flight
```

## Run increasing load

```bash
./scripts/load-test.sh
```

The script uses Bash, `curl`, and `kubectl`. It sustains increasing concurrency
through four timed stages and prints Pod CPU/memory using `kubectl top` every
five seconds. The full run takes about 80 seconds so Metrics Server has enough
time to capture the CPU increase.

## Inspect

```bash
KUBECONFIG=.kubeconfig kubectl -n web-observability get all
KUBECONFIG=.kubeconfig kubectl -n web-observability logs deployment/web
KUBECONFIG=.kubeconfig kubectl -n web-observability logs deployment/prometheus
```

## Destroy

```bash
./scripts/destroy.sh
```
