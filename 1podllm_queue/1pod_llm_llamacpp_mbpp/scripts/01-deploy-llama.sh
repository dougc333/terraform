#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/llama-deployment.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/servicemonitor.yaml
kubectl apply -f k8s/grafana-dashboard.yaml
kubectl -n llm-autoscaling rollout status deployment/llama-server --timeout=20m
kubectl -n llm-autoscaling get pods -o wide
kubectl -n llm-autoscaling get hpa
