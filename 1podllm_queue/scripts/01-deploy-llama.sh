#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-one-pod-lab}"
KIND="${KIND:-$ROOT/.bin/kind}"
DEFAULT_KUBECONFIG="$ROOT/.kubeconfig"
if [[ ! -f "$DEFAULT_KUBECONFIG" && -f "$ROOT/../1pod_llm/.kubeconfig" ]]; then
  DEFAULT_KUBECONFIG="$ROOT/../1pod_llm/.kubeconfig"
fi
export KUBECONFIG="${KUBECONFIG:-$DEFAULT_KUBECONFIG}"

if [[ ! -x "$KIND" ]]; then
  if [[ -x "$ROOT/../1pod_llm/.bin/kind" ]]; then
    KIND="$ROOT/../1pod_llm/.bin/kind"
  elif command -v kind >/dev/null 2>&1; then
    KIND="$(command -v kind)"
  else
    echo "kind is required to load the queue image into the cluster." >&2
    echo "Install it with: GOBIN=$ROOT/.bin go install sigs.k8s.io/kind@v0.31.0" >&2
    exit 1
  fi
fi

docker build --tag local/llama-queue-proxy:dev "$ROOT/queue-proxy"
"$KIND" load docker-image local/llama-queue-proxy:dev --name "$CLUSTER_NAME"

kubectl apply -f "$ROOT/k8s/namespace.yaml"
kubectl apply -f "$ROOT/k8s/llama-deployment.yaml"
kubectl apply -f "$ROOT/k8s/queue-proxy.yaml"
kubectl apply -f "$ROOT/k8s/hpa.yaml"
kubectl apply -f "$ROOT/k8s/servicemonitor.yaml"
kubectl apply -f "$ROOT/k8s/grafana-dashboard.yaml"
kubectl -n llm-autoscaling rollout restart deployment/llama-queue
kubectl -n llm-autoscaling rollout status deployment/llama-server --timeout=20m
kubectl -n llm-autoscaling rollout status deployment/llama-queue --timeout=5m
kubectl -n llm-autoscaling get pods -o wide
kubectl -n llm-autoscaling get hpa
echo "Queue status:"
kubectl -n llm-autoscaling logs deployment/llama-queue --tail=5
