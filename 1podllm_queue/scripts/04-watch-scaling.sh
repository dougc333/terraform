#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_KUBECONFIG="$ROOT/.kubeconfig"
if [[ ! -f "$DEFAULT_KUBECONFIG" && -f "$ROOT/../1pod_llm/.kubeconfig" ]]; then
  DEFAULT_KUBECONFIG="$ROOT/../1pod_llm/.kubeconfig"
fi
export KUBECONFIG="${KUBECONFIG:-$DEFAULT_KUBECONFIG}"
NAMESPACE="llm-autoscaling"
HPA="llama-server"
DEPLOYMENT="llama-server"
INTERVAL="${INTERVAL:-5}"
QUEUE_URL="${QUEUE_URL:-http://127.0.0.1:8080}"
previous_pods=""

echo "Watching llama.cpp autoscaling every ${INTERVAL}s (Ctrl-C to stop)"
echo "A scale event is printed when the HPA's current pod count changes."
echo "Stop the load test to observe scale-down; the HPA has a 60s scale-down stabilization window."
echo

while true; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  if ! hpa_status="$(kubectl -n "$NAMESPACE" get hpa "$HPA" \
    -o jsonpath='{.status.currentReplicas}{"|"}{.status.desiredReplicas}{"|"}{.status.currentMetrics[0].resource.current.averageUtilization}{"|"}{.spec.metrics[0].resource.target.averageUtilization}' \
    2>/dev/null)"; then
    echo "[$timestamp] HPA unavailable; retrying..."
    sleep "$INTERVAL"
    continue
  fi

  IFS='|' read -r current_pods desired_pods cpu_percent target_percent <<<"$hpa_status"
  current_pods="${current_pods:-0}"
  desired_pods="${desired_pods:-0}"
  cpu_percent="${cpu_percent:-warming-up}"
  target_percent="${target_percent:-unknown}"
  ready_pods="$(kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  ready_pods="${ready_pods:-0}"
  queue_depth="$(curl --silent --fail --max-time 2 "$QUEUE_URL/queue-depth" 2>/dev/null || echo unavailable)"

  if [[ -z "$previous_pods" ]]; then
    echo "[$timestamp] INITIAL: $current_pods pod(s)"
    kubectl -n "$NAMESPACE" get pods -l app=llama-server -o wide
  elif [[ "$current_pods" =~ ^[0-9]+$ && "$previous_pods" =~ ^[0-9]+$ && "$current_pods" -gt "$previous_pods" ]]; then
    echo
    echo "[$timestamp] SCALE UP: $previous_pods -> $current_pods pods"
    kubectl -n "$NAMESPACE" get pods -l app=llama-server -o wide
  elif [[ "$current_pods" =~ ^[0-9]+$ && "$previous_pods" =~ ^[0-9]+$ && "$current_pods" -lt "$previous_pods" ]]; then
    echo
    echo "[$timestamp] SCALE DOWN: $previous_pods -> $current_pods pods"
    kubectl -n "$NAMESPACE" get pods -l app=llama-server -o wide
  fi

  echo "[$timestamp] pods=$current_pods desired=$desired_pods ready=$ready_pods cpu=${cpu_percent}% target=${target_percent}% queue=$queue_depth"
  previous_pods="$current_pods"
  sleep "$INTERVAL"
done
