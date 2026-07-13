#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set grafana.sidecar.dashboards.enabled=true --set grafana.sidecar.dashboards.searchNamespace=ALL --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false --wait --timeout 15m
kubectl -n monitoring get pods
