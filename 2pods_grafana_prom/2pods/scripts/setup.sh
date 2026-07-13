#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="two-pod-lab"
KIND_VERSION="v0.32.0"
KIND_NODE_IMAGE="kindest/node:v1.35.0@sha256:452d707d4862f52530247495d180205e029056831160e22870e37e3f6c1ac31f"
export KUBECONFIG="$ROOT/.kubeconfig"

for command in curl docker go kubectl python3 terraform; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is missing: $command" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and retry." >&2
  exit 1
fi

if command -v kind >/dev/null 2>&1; then
  KIND="$(command -v kind)"
else
  KIND="$ROOT/.bin/kind"
  if [[ ! -x "$KIND" ]]; then
    echo "Installing kind $KIND_VERSION into $ROOT/.bin"
    mkdir -p "$ROOT/.bin" "$ROOT/.cache/go-mod" "$ROOT/.cache/go-build"
    GOBIN="$ROOT/.bin" \
      GOPATH="$ROOT/.cache/gopath" \
      GOMODCACHE="$ROOT/.cache/go-mod" \
      GOCACHE="$ROOT/.cache/go-build" \
      go install "sigs.k8s.io/kind@$KIND_VERSION"
  fi
fi

if ! "$KIND" get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  "$KIND" create cluster \
    --name "$CLUSTER_NAME" \
    --image "$KIND_NODE_IMAGE" \
    --config "$ROOT/kind-config.yaml" \
    --kubeconfig "$KUBECONFIG"
else
  "$KIND" export kubeconfig \
    --name "$CLUSTER_NAME" \
    --kubeconfig "$KUBECONFIG"
fi

docker build --tag local/web-autoscale:dev "$ROOT/app"
"$KIND" load docker-image local/web-autoscale:dev --name "$CLUSTER_NAME"

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
  --namespace web-autoscaling \
  --for=condition=Available \
  deployment/web \
  deployment/prometheus \
  deployment/kube-state-metrics \
  deployment/grafana \
  --timeout=300s

echo
echo "Autoscaling lab is ready."
echo "Run: $ROOT/scripts/run-hpa-test.sh"
echo "Open Grafana: $ROOT/scripts/grafana-ui.sh"
