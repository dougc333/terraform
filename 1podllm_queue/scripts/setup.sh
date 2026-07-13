#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="one-pod-lab"
KIND="$ROOT/.bin/kind"
export KUBECONFIG="$ROOT/.kubeconfig"

if [[ ! -x "$KIND" ]]; then
  echo "kind is missing at $KIND" >&2
  echo "Install it with: GOBIN=$ROOT/.bin go install sigs.k8s.io/kind@v0.31.0" >&2
  exit 1
fi

if ! "$KIND" get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  "$KIND" create cluster \
    --name "$CLUSTER_NAME" \
    --image "kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f" \
    --config "$ROOT/kind-config.yaml"
fi

docker build --tag local/web-metrics:dev "$ROOT/app"
"$KIND" load docker-image local/web-metrics:dev --name "$CLUSTER_NAME"

kubectl apply --filename \
  https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml

if ! kubectl get deployment metrics-server \
  --namespace kube-system \
  --output=jsonpath='{.spec.template.spec.containers[0].args}' \
  | grep -q -- '--kubelet-insecure-tls'; then
  kubectl patch deployment metrics-server \
    --namespace kube-system \
    --type=json \
    --patch='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

kubectl rollout status deployment/metrics-server \
  --namespace kube-system \
  --timeout=180s

terraform -chdir="$ROOT" init
terraform -chdir="$ROOT" apply --auto-approve

kubectl wait \
  --namespace web-observability \
  --for=condition=Available \
  deployment/web deployment/prometheus deployment/grafana \
  --timeout=180s

echo
echo "Lab is ready."
echo "Run: $ROOT/scripts/load-test.sh"
echo "Run in another terminal: $ROOT/scripts/prometheus-ui.sh"
echo "Or open the full dashboard: $ROOT/scripts/grafana-ui.sh"
