# llama.cpp FIFO Queue and Autoscaling Lab

The OpenAI-compatible request path now includes an in-cluster FIFO queue proxy:

```text
MBPP load test -> llama-queue Service -> FIFO queue -> 2 forwarding workers -> llama-server Service -> llama.cpp pods
```

The queue preserves synchronous `/v1/chat/completions` responses, prints the number of waiting messages on every enqueue and dequeue, and exposes queue state at `/queue`, plain queue depth at `/queue-depth`, and Prometheus metrics at `/metrics`.

Deploy the llama server and queue after the cluster and monitoring stack are ready:

```bash
./scripts/01-deploy-llama.sh
```

When this folder is beside `/Users/dc/terraform/1pod_llm`, the deployment and watcher scripts automatically reuse that existing local cluster's kubeconfig and `kind` binary if this copy does not have its own.

Use separate terminals:

```bash
./scripts/02-port-forward-llama.sh
```

```bash
./scripts/04-watch-queue.sh
```

```bash
./scripts/04-watch-scaling.sh
```

```bash
WORKERS=12 DURATION=300 ./scripts/03-run-mbpp-load.sh
```

Every completed MBPP request and LLM response is written to a timestamped JSON Lines file under `load/results/`. Each record contains the task ID, task prompt, tests, full request, full response, extracted generated code, latency, and error state. Set an explicit output path when needed:

```bash
RESULTS_FILE=load/results/my-run.jsonl WORKERS=12 DURATION=300 ./scripts/03-run-mbpp-load.sh
```

Example queue output:

```text
[2026-07-13 05:00:00] {"queued":10,"capacity":100,"in_flight":2,"workers":2,"accepted_total":12,"completed_total":0,"failed_total":0,"rejected_total":0}
```

Useful PromQL:

```promql
llama_queue_depth
```

```promql
llama_queue_in_flight
```

# Original One-Pod Kubernetes Observability Lab

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
