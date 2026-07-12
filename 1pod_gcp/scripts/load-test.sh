#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="web-observability"
URL="http://127.0.0.1:18080"
PORT_FORWARD_LOG="${TMPDIR:-/tmp}/one-pod-gcp-web-port-forward.log"

kubectl --namespace "$NAMESPACE" port-forward service/web 18080:8080 \
  >"$PORT_FORWARD_LOG" 2>&1 &
PORT_FORWARD_PID=$!
MONITOR_PID=""

cleanup() {
  if [[ -n "$MONITOR_PID" ]]; then
    kill "$MONITOR_PID" 2>/dev/null || true
  fi
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 30); do
  if curl --silent --fail "$URL/healthz" >/dev/null; then
    break
  fi
  sleep 1
done

if ! curl --silent --fail "$URL/healthz" >/dev/null; then
  echo "web port-forward did not become ready; see $PORT_FORWARD_LOG" >&2
  exit 1
fi

monitor_cpu() {
  while true; do
    echo
    date '+CPU sample %H:%M:%S'
    kubectl top pods \
      --namespace "$NAMESPACE" \
      --selector app.kubernetes.io/name=web \
      2>/dev/null || echo "CPU metrics are warming up"
    sleep 5
  done
}

run_stage() {
  local concurrency="$1"
  local duration="$2"
  local work="$3"
  local deadline
  local pids=()

  echo
  echo "Stage: concurrency=$concurrency duration=${duration}s work=$work"
  deadline=$(($(date +%s) + duration))

  for _ in $(seq 1 "$concurrency"); do
    (
      while [[ $(date +%s) -lt $deadline ]]; do
        curl \
          --silent \
          --show-error \
          --fail \
          --max-time 30 \
          --output /dev/null \
          "$URL/?work=$work"
      done
    ) &
    pids+=("$!")
  done

  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

monitor_cpu &
MONITOR_PID=$!

run_stage 1 10 250000
run_stage 5 15 1000000
run_stage 15 25 3000000
run_stage 30 30 5000000


echo
echo "Load test complete. Prometheus queries:"
echo "  rate(web_requests_total[30s])"
echo "  increase(web_requests_total[1m])"
echo "  rate(process_cpu_seconds_total[1m]) * 100"
echo "  rate(web_request_duration_seconds_sum[30s]) / rate(web_request_duration_seconds_count[30s])"
