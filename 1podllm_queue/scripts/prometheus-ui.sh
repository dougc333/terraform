#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

echo "Prometheus UI: http://127.0.0.1:9090"
echo "Request-rate query: rate(web_requests_total[30s])"
echo "Press Control-C to stop."

if command -v open >/dev/null 2>&1; then
  (sleep 2; open "http://127.0.0.1:9090/query") &
fi

kubectl --namespace web-observability port-forward service/prometheus 9090:9090

