#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
while true; do
  clear; date
  echo "=== HPA ==="; kubectl -n llm-autoscaling get hpa
  echo; echo "=== Deployment ==="; kubectl -n llm-autoscaling get deployment llama-server
  echo; echo "=== Pods ==="; kubectl -n llm-autoscaling get pods -o wide
  echo; echo "=== Resource usage ==="; kubectl -n llm-autoscaling top pods 2>/dev/null || echo "Metrics are not ready yet."
  sleep 5
done
