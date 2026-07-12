#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="$ROOT/.kubeconfig"

for command_name in docker gcloud kubectl terraform; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required but was not found on PATH" >&2
    exit 1
  fi
done

PROJECT_ID="${TF_VAR_project_id:-$(gcloud config get-value project 2>/dev/null)}"
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Set a project first:" >&2
  echo "  gcloud config set project YOUR_PROJECT_ID" >&2
  echo "  export TF_VAR_project_id=YOUR_PROJECT_ID" >&2
  exit 1
fi

export TF_VAR_project_id="$PROJECT_ID"
REGION="${TF_VAR_region:-us-central1}"
ZONE="${TF_VAR_zone:-us-central1-a}"
CLUSTER_NAME="${TF_VAR_cluster_name:-one-pod-gcp-lab}"
REPOSITORY="${TF_VAR_artifact_repository:-one-pod-lab}"
IMAGE_NAME="${TF_VAR_web_image_name:-web-metrics}"
IMAGE_TAG="${TF_VAR_web_image_tag:-dev}"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Project:      $PROJECT_ID"
echo "GKE cluster:  $CLUSTER_NAME ($ZONE)"
echo "Node type:    ${TF_VAR_machine_type:-e2-micro}"
echo "Image:        $IMAGE_URI"
echo

# A copied kind lab can contain an unrelated default local state. Preserve it
# outside the root so Terraform cannot offer to migrate it into the GCP state.
if [[ -f "$ROOT/terraform.tfstate" || -f "$ROOT/terraform.tfstate.backup" ]]; then
  mkdir -p "$ROOT/kind-state-backup"
  if [[ -f "$ROOT/terraform.tfstate" ]]; then
    mv "$ROOT/terraform.tfstate" "$ROOT/kind-state-backup/terraform.tfstate"
  fi
  if [[ -f "$ROOT/terraform.tfstate.backup" ]]; then
    mv "$ROOT/terraform.tfstate.backup" "$ROOT/kind-state-backup/terraform.tfstate.backup"
  fi
  echo "Preserved copied kind state under: $ROOT/kind-state-backup"
fi

# Reconfigure instead of migrating the copied kind state into this GCP backend.
terraform -chdir="$ROOT" init -reconfigure -input=false

# Bootstrap cloud infrastructure before the Kubernetes provider and image exist.
terraform -chdir="$ROOT" apply --auto-approve \
  -target=google_container_node_pool.lab \
  -target=google_artifact_registry_repository.web

rm -f "$KUBECONFIG"
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# GKE E2 nodes are amd64. This also works from an Apple Silicon Mac.
docker buildx build \
  --platform linux/amd64 \
  --tag "$IMAGE_URI" \
  --push \
  "$ROOT/app"

# Reconcile the complete configuration now that the cluster and image exist.
terraform -chdir="$ROOT" apply --auto-approve

kubectl wait \
  --namespace web-observability \
  --for=condition=Available \
  deployment/web deployment/prometheus \
  --timeout=300s

echo
echo "GKE lab is ready. This project creates billable Google Cloud resources."
echo "Run: $ROOT/scripts/load-test.sh"
echo "Run in another terminal: $ROOT/scripts/prometheus-ui.sh"
echo "Destroy when finished: $ROOT/scripts/destroy.sh"
