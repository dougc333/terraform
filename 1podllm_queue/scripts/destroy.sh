#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

terraform -chdir="$ROOT" destroy --auto-approve || true
"$ROOT/.bin/kind" delete cluster --name one-pod-lab
rm -f "$ROOT/.kubeconfig"

