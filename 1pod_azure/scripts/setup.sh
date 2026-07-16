#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

for command_name in az kubectl terraform curl; do
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

LOCATION="${TF_VAR_location:-westus3}"
RESOURCE_GROUP="${TF_VAR_resource_group_name:-one-pod-azure-lab-rg}"
CLUSTER_NAME="${TF_VAR_cluster_name:-one-pod-azure-lab}"
NODE_VM_SIZE="${TF_VAR_node_vm_size:-Standard_D4as_v5}"

SKU_AVAILABLE="$(az vm list-skus \
  --location "$LOCATION" \
  --resource-type virtualMachines \
  --all \
  --query "[?name=='${NODE_VM_SIZE}' && length(restrictions)==\`0\`] | length(@)" \
  --output tsv)"

if [[ "$SKU_AVAILABLE" == "0" ]]; then
  echo "$NODE_VM_SIZE is unavailable or restricted in $LOCATION for this subscription." >&2
  echo "Choose another AKS system-pool SKU with at least 4 vCPUs and 4 GiB, then set TF_VAR_node_vm_size." >&2
  exit 1
fi

echo "Subscription:   $SUBSCRIPTION_ID"
echo "Location:       $LOCATION"
echo "Resource group: $RESOURCE_GROUP"
echo "AKS cluster:    $CLUSTER_NAME"
echo "Node VM size:   $NODE_VM_SIZE"
echo
echo "This creates billable Azure resources. Run scripts/destroy.sh when finished."
echo

terraform -chdir="$ROOT" init -reconfigure -input=false

# Create AKS first so the Kubernetes provider has a reachable API server for
# the second, complete apply.
terraform -chdir="$ROOT" apply --auto-approve \
  -target=azurerm_kubernetes_cluster.lab

rm -f "$KUBECONFIG"
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --file "$KUBECONFIG" \
  --overwrite-existing

terraform -chdir="$ROOT" apply --auto-approve

"$ROOT/scripts/verify.sh"
