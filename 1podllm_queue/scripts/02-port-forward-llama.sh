#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_KUBECONFIG="$ROOT/.kubeconfig"
if [[ ! -f "$DEFAULT_KUBECONFIG" && -f "$ROOT/../1pod_llm/.kubeconfig" ]]; then
  DEFAULT_KUBECONFIG="$ROOT/../1pod_llm/.kubeconfig"
fi
export KUBECONFIG="${KUBECONFIG:-$DEFAULT_KUBECONFIG}"

echo "Forwarding local port 8080 to the llama.cpp FIFO queue proxy"
kubectl -n llm-autoscaling port-forward service/llama-queue 8080:8080
