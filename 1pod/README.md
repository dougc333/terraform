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

## Open the lab UI

In a second terminal:

```bash
./scripts/web-ui.sh
```

The One-Pod Observability Lab opens at <http://127.0.0.1:18080>. Use the CPU
iterations control to send individual workload requests, inspect their response
and duration, and build a short in-browser run history. The UI checks the live
`/healthz` endpoint and sends work to `/api/work`; the original plain-text
`GET /?work=<n>` contract remains available for scripts and direct requests.

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

## Frontend development

The React and TypeScript source lives in `app/ui`. Run the Go service in one
terminal and Vite in another; Vite proxies health and workload API requests to
port 8080:

```bash
cd app
UI_DIST_DIR=ui/dist go run .
```

```bash
cd app/ui
npm ci
npm run dev
```

Open <http://127.0.0.1:5173>. To test and build the production assets:

```bash
cd app/ui
npm test
npm run build
```

The application container uses a Node build stage and copies the generated
static assets into the final distroless image; Node is not present at runtime.

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
