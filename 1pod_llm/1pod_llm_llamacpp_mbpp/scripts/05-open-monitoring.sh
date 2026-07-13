#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-.kubeconfig}"
PW="$(kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
echo "Grafana: http://127.0.0.1:3000  user=admin password=${PW}"
echo "Prometheus: http://127.0.0.1:9090"
kubectl -n monitoring port-forward service/monitoring-grafana 3000:80 >/tmp/llama-grafana.log 2>&1 & echo $! >/tmp/llama-grafana.pid
kubectl -n monitoring port-forward service/monitoring-kube-prometheus-prometheus 9090:9090 >/tmp/llama-prometheus.log 2>&1 & echo $! >/tmp/llama-prometheus.pid
