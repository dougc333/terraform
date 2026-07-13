#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="${NAMESPACE:-web-autoscaling}"
RUN_ID="${1:-$(date '+%Y%m%d-%H%M%S')}"
RESULTS_DIR="$ROOT/results"
RESULT_FILE="$RESULTS_DIR/metrics-verification-$RUN_ID.txt"
PROMETHEUS_URL="http://127.0.0.1:19090"
GRAFANA_URL="http://127.0.0.1:13000"
PROM_LOG="${TMPDIR:-/tmp}/two-pod-prometheus-port-forward.log"
GRAFANA_LOG="${TMPDIR:-/tmp}/two-pod-grafana-port-forward.log"

mkdir -p "$RESULTS_DIR"

kubectl --namespace "$NAMESPACE" port-forward service/prometheus 19090:9090 \
  >"$PROM_LOG" 2>&1 &
PROM_PID=$!

kubectl --namespace "$NAMESPACE" port-forward service/grafana 13000:3000 \
  >"$GRAFANA_LOG" 2>&1 &
GRAFANA_PID=$!

cleanup() {
  kill "$PROM_PID" "$GRAFANA_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 30); do
  if curl --silent --fail "$PROMETHEUS_URL/-/ready" >/dev/null \
    && curl --silent --fail "$GRAFANA_URL/api/health" >/dev/null; then
    break
  fi
  sleep 1
done

if ! curl --silent --fail "$PROMETHEUS_URL/-/ready" >/dev/null; then
  echo "Prometheus port-forward is not ready; see $PROM_LOG" >&2
  exit 1
fi

if ! curl --silent --fail "$GRAFANA_URL/api/health" >/dev/null; then
  echo "Grafana port-forward is not ready; see $GRAFANA_LOG" >&2
  exit 1
fi

query_value() {
  local expression="$1"

  curl --silent --fail --get \
    --data-urlencode "query=$expression" \
    "$PROMETHEUS_URL/api/v1/query" \
    | python3 -c '
import json, sys
payload = json.load(sys.stdin)
results = payload.get("data", {}).get("result", [])
if not results:
    raise SystemExit("query returned no data")
print(results[0]["value"][1])
'
}

max_replicas="$(query_value 'max_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="web-autoscaling",horizontalpodautoscaler="web"}[15m])')"
final_replicas="$(query_value 'kube_horizontalpodautoscaler_status_current_replicas{namespace="web-autoscaling",horizontalpodautoscaler="web"}')"
max_request_rate="$(query_value 'max_over_time((sum(rate(k6_http_reqs_total[15s])))[15m:5s])')"
min_request_rate="$(query_value 'min_over_time((sum(rate(k6_http_reqs_total[15s])))[15m:5s])')"
max_cpu="$(query_value 'max_over_time((avg(rate(process_cpu_seconds_total{job="web"}[30s])) / 0.2 * 100)[15m:5s])')"

curl --silent --fail "$GRAFANA_URL/api/dashboards/uid/hpa-autoscaling" >/dev/null

{
  echo "Prometheus/Grafana verification"
  echo "max_replicas=$max_replicas"
  echo "final_replicas=$final_replicas"
  echo "max_k6_requests_per_second=$max_request_rate"
  echo "min_k6_requests_per_second=$min_request_rate"
  echo "max_hpa_cpu_percent=$max_cpu"
  echo "grafana_dashboard=provisioned"
} | tee "$RESULT_FILE"

python3 - \
  "$max_replicas" \
  "$final_replicas" \
  "$max_request_rate" \
  "$min_request_rate" \
  "$max_cpu" <<'PY'
import sys

max_replicas, final_replicas, max_rate, min_rate, max_cpu = map(float, sys.argv[1:])
failures = []

if max_replicas < 2:
    failures.append(f"replica graph never reached 2 (max={max_replicas})")
if final_replicas != 1:
    failures.append(f"replicas did not finish at 1 (final={final_replicas})")
if max_rate < 10:
    failures.append(f"traffic graph did not ramp high enough (max={max_rate})")
if min_rate > 5:
    failures.append(f"traffic graph did not ramp down (min={min_rate})")
if max_cpu <= 50:
    failures.append(f"CPU graph did not cross the HPA target (max={max_cpu})")

if failures:
    raise SystemExit("; ".join(failures))
PY

echo "PASS: Prometheus contains ramp-up/down and 1 -> 2 -> 1 replica history."
echo "PASS: Grafana dashboard is provisioned and queryable."
echo "Metrics verification: $RESULT_FILE"
