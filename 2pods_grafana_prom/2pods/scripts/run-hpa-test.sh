#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="${NAMESPACE:-web-autoscaling}"
JOB_NAME="k6-hpa-load"
RESULTS_DIR="$ROOT/results"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
TIMELINE="$RESULTS_DIR/hpa-timeline-$TIMESTAMP.tsv"
TEST_TIMEOUT_SECONDS=720

mkdir -p "$RESULTS_DIR"

kubectl wait \
  --namespace "$NAMESPACE" \
  --for=condition=Available \
  deployment/web \
  deployment/prometheus \
  deployment/kube-state-metrics \
  deployment/grafana \
  --timeout=180s

if ! kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes >/dev/null; then
  echo "Metrics API is unavailable; check the metrics-server deployment." >&2
  exit 1
fi

echo "Waiting for a one-Pod idle baseline before starting k6..."
baseline_deadline=$((SECONDS + 240))
while (( SECONDS < baseline_deadline )); do
  current="$(kubectl get hpa web --namespace "$NAMESPACE" --output=jsonpath='{.status.currentReplicas}' 2>/dev/null || true)"
  desired="$(kubectl get hpa web --namespace "$NAMESPACE" --output=jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)"
  if [[ "$current" == "1" && "$desired" == "1" ]]; then
    break
  fi
  sleep 5
done

if [[ "${current:-}" != "1" || "${desired:-}" != "1" ]]; then
  echo "HPA did not return to the one-Pod baseline." >&2
  kubectl describe hpa web --namespace "$NAMESPACE" >&2
  exit 1
fi

kubectl delete job "$JOB_NAME" \
  --namespace "$NAMESPACE" \
  --ignore-not-found \
  --wait=true

kubectl apply \
  --namespace "$NAMESPACE" \
  --filename "$ROOT/k6-job.yaml"

printf 'timestamp\tcpu_percent\tdesired_replicas\tcurrent_replicas\tready_replicas\tjob_state\n' \
  | tee "$TIMELINE"

scaled_up=false
scaled_down=false
job_succeeded=false
deadline=$((SECONDS + TEST_TIMEOUT_SECONDS))

while (( SECONDS < deadline )); do
  now="$(date '+%H:%M:%S')"
  cpu="$(kubectl get hpa web --namespace "$NAMESPACE" --output=jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)"
  desired="$(kubectl get hpa web --namespace "$NAMESPACE" --output=jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)"
  current="$(kubectl get hpa web --namespace "$NAMESPACE" --output=jsonpath='{.status.currentReplicas}' 2>/dev/null || true)"
  ready="$(kubectl get deployment web --namespace "$NAMESPACE" --output=jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  succeeded="$(kubectl get job "$JOB_NAME" --namespace "$NAMESPACE" --output=jsonpath='{.status.succeeded}' 2>/dev/null || true)"
  failed="$(kubectl get job "$JOB_NAME" --namespace "$NAMESPACE" --output=jsonpath='{.status.failed}' 2>/dev/null || true)"
  active="$(kubectl get job "$JOB_NAME" --namespace "$NAMESPACE" --output=jsonpath='{.status.active}' 2>/dev/null || true)"

  cpu="${cpu:--}"
  desired="${desired:-0}"
  current="${current:-0}"
  ready="${ready:-0}"

  if [[ "${failed:-0}" -gt 0 ]]; then
    job_state="Failed"
  elif [[ "${succeeded:-0}" -gt 0 ]]; then
    job_state="Complete"
    job_succeeded=true
  elif [[ "${active:-0}" -gt 0 ]]; then
    job_state="Running"
  else
    job_state="Pending"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$now" "$cpu" "$desired" "$current" "$ready" "$job_state" \
    | tee -a "$TIMELINE"

  if (( current >= 2 && ready >= 2 )); then
    scaled_up=true
  fi

  if [[ "$scaled_up" == true ]] && (( current == 1 && desired == 1 && ready == 1 )); then
    scaled_down=true
  fi

  if [[ "$job_state" == "Failed" ]]; then
    echo
    kubectl logs "job/$JOB_NAME" --namespace "$NAMESPACE" || true
    echo "k6 Job failed." >&2
    exit 1
  fi

  if [[ "$job_succeeded" == true && "$scaled_up" == true && "$scaled_down" == true ]]; then
    break
  fi

  sleep 5
done

echo
kubectl logs "job/$JOB_NAME" --namespace "$NAMESPACE" || true

if [[ "$job_succeeded" != true ]]; then
  echo "Timed out before the k6 Job completed." >&2
  exit 1
fi

if [[ "$scaled_up" != true ]]; then
  echo "FAIL: the test never observed two Ready web Pods." >&2
  exit 1
fi

if [[ "$scaled_down" != true ]]; then
  echo "FAIL: the test never observed the HPA return from two Pods to one." >&2
  exit 1
fi

echo
echo "PASS: observed HPA scale 1 -> 2 -> 1 while k6 raised and lowered traffic."
echo "Timeline: $TIMELINE"

"$ROOT/scripts/verify-observability.sh" "$TIMESTAMP"
