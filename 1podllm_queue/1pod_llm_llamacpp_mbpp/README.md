# llama.cpp + Qwen + MBPP autoscaling overlay

Copy these directories into `/Users/dc/terraform/1pod_llm` while preserving the existing Terraform files.

The workload uses the official llama.cpp server container and `Qwen/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M`. It exposes llama.cpp Prometheus metrics, scales from 1 to 6 replicas based on average CPU utilization, and sends MBPP coding prompts through the OpenAI-compatible chat endpoint.

## Install

```bash
cd /Users/dc/terraform/1pod_llm
unzip ~/Downloads/1pod_llm_llamacpp_mbpp_overlay.zip
cp -R 1pod_llm_llamacpp_mbpp/{k8s,load,grafana,scripts} .
chmod +x scripts/*.sh
export KUBECONFIG="$PWD/.kubeconfig"
```

## Run sequence

```bash
terraform init
terraform apply -auto-approve
export KUBECONFIG="$PWD/.kubeconfig"
kubectl get nodes
kubectl top nodes
./scripts/00-install-monitoring.sh
./scripts/01-deploy-llama.sh
```

The first llama.cpp pod must download the GGUF model. Watch startup with:

```bash
kubectl -n llm-autoscaling get pods -w
kubectl -n llm-autoscaling logs -f deploy/llama-server
```

Use four terminals:

```bash
# Terminal 1: endpoint
./scripts/02-port-forward-llama.sh
```

```bash
# Terminal 2: Grafana and Prometheus
./scripts/05-open-monitoring.sh
```

```bash
# Terminal 3: scaling status loop
./scripts/04-watch-scaling.sh
```

```bash
# Terminal 4: MBPP load
WORKERS=12 DURATION=600 ./scripts/03-run-mbpp-load.sh
```

Increase load if CPU stays below 55%:

```bash
WORKERS=24 DURATION=900 ./scripts/03-run-mbpp-load.sh
```

Grafana is at `http://127.0.0.1:3000`; the monitoring script prints the password. Prometheus is at `http://127.0.0.1:9090`.

Useful PromQL:

```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="llm-autoscaling",horizontalpodautoscaler="llama-server"}
```

```promql
kube_horizontalpodautoscaler_status_desired_replicas{namespace="llm-autoscaling",horizontalpodautoscaler="llama-server"}
```

```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="llm-autoscaling",container="llama-server"}[1m]))
```

Confirm the exact llama.cpp metric names in your image:

```bash
curl -s http://127.0.0.1:8080/metrics | grep '^llamacpp' | head -50
```

Stop the load and wait about 60 seconds to see scale-down. Then destroy:

```bash
./scripts/06-stop-port-forwards.sh
./scripts/08-destroy-cluster.sh
```

## Important

Each new pod downloads its own GGUF unless you add a shared/preloaded model volume or bake the model into an image. That means scale-up may be slower than a normal web app. Also ensure Metrics Server is installed, because the HPA uses CPU resource metrics.
