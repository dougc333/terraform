#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="${NAMESPACE:-web-autoscaling}"
URL="http://127.0.0.1:3000/d/hpa-autoscaling/hpa-autoscaling-lab?orgId=1&refresh=5s&from=now-15m&to=now"

echo "Opening Grafana HPA dashboard: $URL"
open "$URL" >/dev/null 2>&1 || true

kubectl --namespace "$NAMESPACE" port-forward service/grafana 3000:3000
