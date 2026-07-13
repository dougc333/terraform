#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="${NAMESPACE:-web-autoscaling}"

echo "Prometheus: http://127.0.0.1:9090"
kubectl --namespace "$NAMESPACE" port-forward service/prometheus 9090:9090
