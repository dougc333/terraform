#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="two-pod-lab"

if command -v kind >/dev/null 2>&1; then
  KIND="$(command -v kind)"
else
  KIND="$ROOT/.bin/kind"
fi

if [[ ! -x "$KIND" ]]; then
  echo "kind is not installed; nothing to destroy."
  exit 0
fi

"$KIND" delete cluster --name "$CLUSTER_NAME"
rm -f "$ROOT/.kubeconfig"
