#!/usr/bin/env bash
set -euo pipefail

QUEUE_URL="${QUEUE_URL:-http://127.0.0.1:8080}"
INTERVAL="${INTERVAL:-1}"

echo "Watching llama.cpp queue depth every ${INTERVAL}s (Ctrl-C to stop)"
while true; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  if status="$(curl --silent --show-error --fail --max-time 2 "$QUEUE_URL/queue" 2>/dev/null)"; then
    echo "[$timestamp] $status"
  else
    echo "[$timestamp] queue unavailable at $QUEUE_URL"
  fi
  sleep "$INTERVAL"
done
