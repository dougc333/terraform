#!/usr/bin/env python3
import os
import sys
import time
import signal
import subprocess
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# --- Configuration & Setup ---
ROOT = Path(__file__).resolve().parent.parent
os.environ["KUBECONFIG"] = str(ROOT / ".kubeconfig")

NAMESPACE = "web-observability"
URL = "http://127.0.0.1:18080"
PORT_FORWARD_LOG = Path(os.environ.get("TMPDIR", "/tmp")) / "one-pod-web-port-forward.log"

# Global state for cleanup
pf_proc = None
log_file = None
stop_monitor_event = threading.Event()

def cleanup():
    """Mirrors the bash trap cleanup function."""
    stop_monitor_event.set()  # Signal the monitor thread to stop
    
    if pf_proc:
        pf_proc.terminate()
        try:
            pf_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pf_proc.kill()
            
    if log_file and not log_file.closed:
        log_file.close()

def signal_handler(sig, frame):
    cleanup()
    sys.exit(0)

# Register signal handlers (equivalent to `trap cleanup EXIT INT TERM`)
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def monitor_cpu():
    """Mirrors the bash monitor_cpu function."""
    while not stop_monitor_event.is_set():
        print()
        print(f"CPU sample {time.strftime('%H:%M:%S')}")
        try:
            subprocess.run(
                ["kubectl", "top", "pods", "--namespace", NAMESPACE, 
                 "--selector", "app.kubernetes.io/name=web"],
                check=False,
                stdout=sys.stdout,
                stderr=subprocess.DEVNULL
            )
        except FileNotFoundError:
            print("CPU metrics are warming up (kubectl not found)")
            
        # Use event.wait() instead of time.sleep() so it reacts instantly to cleanup
        stop_monitor_event.wait(5)

def run_stage(concurrency: int, duration: int, work: int):
    """Mirrors the bash run_stage function using a thread pool."""
    print(f"\nStage: concurrency={concurrency} duration={duration}s work={work}")
    deadline = time.time() + duration

    def worker():
        while time.time() < deadline:
            try:
                # Mimics: curl --silent --show-error --fail --max-time 30 --output /dev/null
                requests.get(f"{URL}/?work={work}", timeout=30)
            except requests.exceptions.RequestException:
                # Catch timeouts, connection errors, etc., but keep looping until deadline
                pass

    # Spawn threads instead of background bash processes
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(worker) for _ in range(concurrency)]
        for future in as_completed(futures):
            # Re-raise any unexpected thread exceptions
            future.result()

# --- Main Execution ---
try:
    # 1. Start port-forward in the background
    log_file = open(PORT_FORWARD_LOG, "w")
    pf_proc = subprocess.Popen(
        ["kubectl", "--namespace", NAMESPACE, "port-forward", "service/web", "18080:8080"],
        stdout=log_file,
        stderr=subprocess.STDOUT
    )

    # 2. Wait for readiness (equivalent to the 30-iteration loop)
    print("Waiting for port-forward to become ready...")
    for _ in range(30):
        try:
            if requests.get(f"{URL}/healthz", timeout=2).ok:
                break
        except requests.exceptions.RequestException:
            pass
        time.sleep(1)
    else:
        # Executed if the loop didn't 'break'
