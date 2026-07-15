#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

LAB_URL="http://127.0.0.1:18080"

echo "One-Pod lab UI: $LAB_URL"
echo "Press Control-C to stop."

if command -v open >/dev/null 2>&1; then
  (sleep 2; open "$LAB_URL") &
fi

kubectl --namespace web-observability port-forward service/web 18080:8080
