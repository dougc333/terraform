#!/usr/bin/env bash
set -euo pipefail
for f in /tmp/llama-grafana.pid /tmp/llama-prometheus.pid; do [[ -f "$f" ]] && kill "$(cat "$f")" 2>/dev/null || true; rm -f "$f"; done
pkill -f "port-forward service/llama-server 8080:8080" 2>/dev/null || true
pkill -f "port-forward service/llama-queue 8080:8080" 2>/dev/null || true
