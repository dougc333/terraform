#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
kubectl delete namespace llm-autoscaling --ignore-not-found
kubectl -n monitoring delete configmap llama-mbpp-grafana-dashboard --ignore-not-found
