#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"
NAMESPACE="${TF_VAR_namespace:-hello-world}"

for command_name in kubectl curl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required but was not found on PATH" >&2
    exit 1
  fi
done

kubectl wait \
  --namespace "$NAMESPACE" \
  --for=condition=Available \
  deployment/hello-world \
  --timeout=300s

DESIRED_REPLICAS="$(kubectl --namespace "$NAMESPACE" get deployment hello-world --output=jsonpath='{.spec.replicas}')"
READY_REPLICAS="$(kubectl --namespace "$NAMESPACE" get deployment hello-world --output=jsonpath='{.status.readyReplicas}')"
POD_COUNT="$(kubectl --namespace "$NAMESPACE" get pods --selector app.kubernetes.io/name=hello-world --field-selector status.phase=Running --no-headers | wc -l | tr -d ' ')"

if [[ "$DESIRED_REPLICAS" != "1" || "$READY_REPLICAS" != "1" || "$POD_COUNT" != "1" ]]; then
  echo "One-Pod invariant failed: desired=$DESIRED_REPLICAS ready=$READY_REPLICAS running=$POD_COUNT" >&2
  kubectl --namespace "$NAMESPACE" get deployment,pods,service --output=wide >&2
  exit 1
fi

PUBLIC_IP=""
HTTP_READY="false"
for _ in $(seq 1 60); do
  PUBLIC_IP="$(kubectl --namespace "$NAMESPACE" get service hello-world --output=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ -n "$PUBLIC_IP" ]] && \
     curl --noproxy '*' --silent --fail --max-time 10 "http://$PUBLIC_IP/healthz" >/dev/null && \
     curl --noproxy '*' --silent --fail --max-time 10 "http://$PUBLIC_IP/ping" >/dev/null; then
    HTTP_READY="true"
    break
  fi
  sleep 5
done

if [[ -z "$PUBLIC_IP" ]]; then
  echo "Azure Load Balancer did not receive a public IP." >&2
  kubectl --namespace "$NAMESPACE" describe service hello-world >&2
  exit 1
fi

if [[ "$HTTP_READY" != "true" ]]; then
  echo "The public IP $PUBLIC_IP was assigned, but the HTTP endpoints did not become ready." >&2
  kubectl --namespace "$NAMESPACE" get deployment,pods,service --output=wide >&2
  exit 1
fi

PING_BODY="$(curl --noproxy '*' --silent --fail --max-time 10 "http://$PUBLIC_IP/ping")"
if [[ "$PING_BODY" != "pong" ]]; then
  echo "Unexpected ping response from http://$PUBLIC_IP/ping: $PING_BODY" >&2
  exit 1
fi

BODY="$(curl --noproxy '*' --silent --fail --max-time 10 "http://$PUBLIC_IP")"
if [[ "$BODY" != *"Hello from Azure Kubernetes Service!"* ]]; then
  echo "Unexpected Hello World response from http://$PUBLIC_IP" >&2
  exit 1
fi

echo
echo "Verification passed."
echo "  Desired web Pods: 1"
echo "  Ready web Pods:   1"
echo "  Running web Pods: 1"
echo "  Hello World URL:  http://$PUBLIC_IP"
echo "  HTTP ping:        http://$PUBLIC_IP/ping -> pong"
echo
kubectl --namespace "$NAMESPACE" get deployment,pods,service --output=wide
