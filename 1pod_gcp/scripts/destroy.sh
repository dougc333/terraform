#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

PROJECT_ID="${TF_VAR_project_id:-$(gcloud config get-value project 2>/dev/null)}"
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Set TF_VAR_project_id to the project used by setup.sh" >&2
  exit 1
fi

export TF_VAR_project_id="$PROJECT_ID"

terraform -chdir="$ROOT" init -reconfigure -input=false
terraform -chdir="$ROOT" destroy --auto-approve
rm -f "$ROOT/.kubeconfig"

echo "GKE cluster, node, network, and Artifact Registry repository destroyed."
