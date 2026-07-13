#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
kubectl -n llm-autoscaling port-forward service/llama-server 8080:8080
