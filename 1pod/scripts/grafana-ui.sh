#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

DASHBOARD_URL="http://127.0.0.1:3000/d/one-pod-overview/one-pod-observability"

echo "Grafana dashboard: $DASHBOARD_URL"
echo "Anonymous local access is enabled; no login is required."
echo "Press Control-C to stop."

if command -v open >/dev/null 2>&1; then
  (sleep 3; open "$DASHBOARD_URL") &
fi

kubectl --namespace web-observability port-forward service/grafana 3000:3000
