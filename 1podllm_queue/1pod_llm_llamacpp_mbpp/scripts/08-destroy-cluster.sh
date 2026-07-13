#!/usr/bin/env bash
set -euo pipefail
./scripts/06-stop-port-forwards.sh || true
terraform destroy -auto-approve
