#!/usr/bin/env bash
set -euo pipefail
python3 -m venv .venv-load
source .venv-load/bin/activate
python -m pip install -r load/requirements.txt
python load/mbpp_load.py --url http://127.0.0.1:8080 --workers "${WORKERS:-12}" --duration "${DURATION:-600}" --tasks "${TASKS:-100}" --max-tokens "${MAX_TOKENS:-192}"
