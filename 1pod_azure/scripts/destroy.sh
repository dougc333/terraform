#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

for command_name in az terraform; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required but was not found on PATH" >&2
    exit 1
  fi
done

if ! az account show >/dev/null 2>&1; then
  echo "Sign in to Azure first: az login" >&2
  exit 1
fi

SUBSCRIPTION_ID="${TF_VAR_subscription_id:-$(az account show --query id --output tsv)}"
if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "No active Azure subscription was found." >&2
  exit 1
fi
export TF_VAR_subscription_id="$SUBSCRIPTION_ID"

terraform -chdir="$ROOT" init -reconfigure -input=false
terraform -chdir="$ROOT" destroy --auto-approve
rm -f "$KUBECONFIG"

echo "The AKS cluster, public Load Balancer, and resource group were destroyed."

